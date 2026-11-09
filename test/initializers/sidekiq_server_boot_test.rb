require "test_helper"
require "open3"
require "rbconfig"

# Boots the dummy app in a fresh process the way the Sidekiq CLI does (Sidekiq::CLI defined, so
# Sidekiq.configure_server blocks run), without processing jobs. An in-process test can't see a
# server-only crash: in the mytask-imas pilot the worker restarted forever with "uninitialized
# constant" in its Sidekiq initializer while the backend and every other test stayed green.
class SidekiqServerBootTest < ActiveSupport::TestCase
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)

  # Runs +script+ after booting the dummy app as a Sidekiq server; returns [output, status].
  def boot_as_sidekiq_server(script)
    boot = <<~'RUBY'
      require "sidekiq/cli"
      require "./config/environment"
    RUBY
    Open3.capture2e({ "RAILS_ENV" => "test" }, RbConfig.ruby, "-e", boot + script, chdir: DUMMY_ROOT)
  end

  def assert_booted(output, status)
    errors = output.lines.grep(/Error|uninitialized/).first(5).join
    assert status.success?, "booting as a Sidekiq server failed:\n#{errors.presence || output.lines.last(20).join}"
  end

  test "the app boots as a Sidekiq server with job retries off, one failure kept and the generic death handler registered once" do
    output, status = boot_as_sidekiq_server(<<~'RUBY')
      puts "retry=#{Sidekiq.default_job_options['retry'].inspect}"
      puts "failures_max_count=#{Sidekiq.failures_max_count.inspect}"
      puts "handlers=#{Sidekiq.default_configuration.death_handlers.map(&:to_s).inspect}"
    RUBY

    assert_booted(output, status)
    assert_match(/^retry=false$/, output)
    assert_match(/^failures_max_count=1$/, output)
    handlers = output[/^handlers=(.*)$/, 1].to_s
    assert_equal 1, handlers.scan('"ThecoreBackendCommons::DiscardedJobLogger"').size, "death handlers: #{handlers}"
  end

  # Runs a failing mailer job (as ActiveJob enqueues it) through Sidekiq's own JobRetry, the path a
  # real worker takes, with the death handlers registered at boot. No Redis needed: with retries off
  # JobRetry calls the death handlers and never touches the retry or dead sets.
  test "a failed job is recorded in the Rails log with its identity and error, never its arguments" do
    output, status = boot_as_sidekiq_server(<<~'RUBY')
      require "sidekiq/job_retry"
      Rails.logger = ActiveSupport::Logger.new($stdout)
      job = {
        "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "ActionMailer::MailDeliveryJob",
        "queue" => "app_default", "jid" => "abc123jid", "retry" => false,
        "args" => [{ "job_class" => "ActionMailer::MailDeliveryJob",
                     "arguments" => ["ReportMailer", "report_pdf_email", "deliver_now",
                                     { "params" => { "pdf_content" => "SECRET-PDF-PAYLOAD" } }] }]
      }
      retrier = Sidekiq::JobRetry.new(Sidekiq.default_configuration.default_capsule)
      begin
        retrier.global(Sidekiq.dump_json(job), "app_default") { raise Net::SMTPFatalError, "552 message size exceeds limit" }
      rescue Sidekiq::JobRetry::Handled
        puts "handled"
      end
    RUBY

    assert_booted(output, status)
    assert_match(/^handled$/, output)
    failure = output.lines.grep(/abc123jid/).join
    assert_includes failure, "ReportMailer#report_pdf_email"
    assert_includes failure, "app_default"
    assert_includes failure, "Net::SMTPFatalError: 552 message size exceeds limit"
    assert_not_includes output, "SECRET-PDF-PAYLOAD", "the job's arguments must never be logged"
  end

  # sidekiq-failures (loaded by thecore_background_jobs) stores each failed job's full payload,
  # arguments included, in the Redis `failed` sorted set and trims it to the last
  # Sidekiq.failures_max_count after each failure. Runs two failing jobs through the server
  # middleware chain registered at boot, against a real Redis (REDIS_URL, DB 15 in the devcontainer).
  test "after two failed jobs the Redis failed set holds only the latest" do
    redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/15")
    output, status = boot_as_sidekiq_server(<<~RUBY)
      Sidekiq.configure_server { |c| c.redis = { url: #{redis_url.inspect} } }
      begin
        Sidekiq.redis { |r| r.call("PING") }
      rescue StandardError => e
        puts "no-redis: \#{e.class}"
        exit 0
      end
      Sidekiq.redis { |r| r.del("failed") }
      chain = Sidekiq.default_configuration.server_middleware
      %w[first-jid second-jid].each do |jid|
        msg = { "class" => "SomeJob", "queue" => "app_default", "jid" => jid, "retry" => false, "args" => ["PAYLOAD-\#{jid}"] }
        begin
          chain.invoke(Object.new, msg, "app_default") { raise "boom \#{jid}" }
        rescue RuntimeError
          nil
        end
      end
      Sidekiq.redis do |r|
        puts "failed_count=\#{r.zcard('failed')}"
        r.zrange("failed", 0, -1).each { |payload| puts "failed_jid=\#{Sidekiq.load_json(payload)['jid']}" }
        r.del("failed")
      end
    RUBY

    assert_booted(output, status)
    skip "no Redis at #{redis_url}" if output.include?("no-redis:")
    assert_match(/^failed_count=1$/, output)
    assert_equal ["second-jid"], output.scan(/^failed_jid=(.*)$/).flatten
  end

  # A failing job runs exactly once: a plain ActiveJob and a mail job (ActionMailer::MailDeliveryJob)
  # are enqueued through the Sidekiq adapter into a real Redis and processed by Sidekiq's own
  # Processor (fetch, server middleware, JobRetry), the path a worker takes. Afterwards nothing is
  # waiting to run again: the queue, the retry set and the schedule set are empty, and the failures
  # set holds at most one entry.
  test "a failing ActiveJob and a failing mail job each run exactly once and are never re-enqueued" do
    redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/15")
    output, status = boot_as_sidekiq_server(<<~RUBY)
      require "sidekiq/rails" # as Sidekiq::CLI#boot_application does
      require "sidekiq/processor"
      Sidekiq.configure_server { |c| c.redis = { url: #{redis_url.inspect} } }
      begin
        Sidekiq.redis { |r| r.call("PING") }
      rescue StandardError => e
        puts "no-redis: \#{e.class}"
        exit 0
      end
      Rails.logger = ActiveSupport::Logger.new(File::NULL)
      Sidekiq.default_configuration.logger = Logger.new(File::NULL)
      Sidekiq.redis { |r| r.flushdb }

      class AlwaysFailingJob < ActiveJob::Base
        def perform(payload)
          Sidekiq.redis { |r| r.incr("executions:job") }
          raise "job failed"
        end
      end

      class AlwaysFailingMailer < ActionMailer::Base
        def failing_email
          Sidekiq.redis { |r| r.incr("executions:mail") }
          raise "mail failed"
        end
      end

      ActiveJob::Base.queue_adapter = :sidekiq
      AlwaysFailingJob.set(queue: "default").perform_later("PAYLOAD")
      AlwaysFailingMailer.failing_email.deliver_later(queue: "default")

      capsule = Sidekiq.default_configuration.default_capsule
      capsule.queues = ["default"]
      processor = Sidekiq::Processor.new(capsule) { nil }
      # Two jobs, then one more fetch that must find nothing to run again.
      3.times do
        processor.send(:process_one) # private: the body of Processor#run's loop
      rescue StandardError => e
        puts "process_one: \#{e.class}: \#{e.message}"
      end

      Sidekiq.redis do |r|
        puts "executions_job=\#{r.get('executions:job').to_i}"
        puts "executions_mail=\#{r.get('executions:mail').to_i}"
        puts "queue=\#{r.llen('queue:default')}"
        puts "retry=\#{r.zcard('retry')}"
        puts "schedule=\#{r.zcard('schedule')}"
        puts "dead=\#{r.zcard('dead')}"
        puts "failed=\#{r.zcard('failed')}"
        r.flushdb
      end
    RUBY

    assert_booted(output, status)
    skip "no Redis at #{redis_url}" if output.include?("no-redis:")
    assert_match(/^executions_job=1$/, output, output)
    assert_match(/^executions_mail=1$/, output, output)
    assert_match(/^queue=0$/, output, output)
    assert_match(/^retry=0$/, output, output)
    assert_match(/^schedule=0$/, output, output)
    assert_match(/^dead=0$/, output, output)
    assert_operator output[/^failed=(\d+)$/, 1].to_i, :<=, 1, output
  end
end
