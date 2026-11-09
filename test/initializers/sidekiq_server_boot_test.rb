require "test_helper"
require "open3"
require "rbconfig"

# Boots the dummy app in a fresh process the way the Sidekiq CLI does (Sidekiq::CLI defined, so
# Sidekiq.configure_server blocks run), without processing jobs. An in-process test can't see a
# server-only crash: in the mytask-imas pilot the worker restarted forever with "uninitialized
# constant" in its Sidekiq initializer while the backend and every other test stayed green.
class SidekiqServerBootTest < ActiveSupport::TestCase
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)

  REDIS_URL = ENV.fetch("REDIS_URL", "redis://redis:6379/15")
  # The two knobs are unset unless a test sets them, whatever the environment running the tests.
  KNOBS_UNSET = { "THECORE_JOB_RETRIES" => nil, "THECORE_FAILED_JOBS_KEPT" => nil }.freeze

  # Runs +script+ after booting the dummy app as a Sidekiq server with +env+; returns [output, status].
  def boot_as_sidekiq_server(script, env = {})
    boot = <<~'RUBY'
      require "sidekiq/cli"
      # As Sidekiq::CLI#boot_application does: sidekiq/rails before the app, so its engine
      # initializers run (sidekiq_options on ActiveJob classes, the reloader).
      require "rails"
      require "sidekiq/rails"
      require "./config/environment"
    RUBY
    Open3.capture2e({ "RAILS_ENV" => "test" }.merge(KNOBS_UNSET, env), RbConfig.ruby, "-e", boot + script, chdir: DUMMY_ROOT)
  end

  # Boots as a Sidekiq server on a real Redis (flushed before and after), runs +jobs+ (Ruby that
  # defines job classes and enqueues +count+ jobs on the "default" queue through the Sidekiq
  # ActiveJob adapter), then processes them with Sidekiq's own Processor (fetch, server middleware,
  # JobRetry), the path a worker takes, plus one more fetch that must find nothing. Prints each
  # `executions:<name>` counter the jobs increment, the sizes of the queue and of the retry,
  # schedule, dead and failed sets, and the wrapped class of each job in the retry set.
  # Returns [output, status]; skips the test when Redis is unreachable.
  def process_jobs_on_redis(jobs, count:, env: {})
    output, status = boot_as_sidekiq_server(<<~RUBY, env)
      require "sidekiq/processor"
      Sidekiq.configure_server { |c| c.redis = { url: #{REDIS_URL.inspect} } }
      begin
        Sidekiq.redis { |r| r.call("PING") }
      rescue StandardError => e
        puts "no-redis: \#{e.class}"
        exit 0
      end
      Rails.logger = ActiveSupport::Logger.new(File::NULL)
      Sidekiq.default_configuration.logger = Logger.new(File::NULL)
      Sidekiq.redis { |r| r.flushdb }
      ActiveJob::Base.queue_adapter = :sidekiq

      #{jobs}

      capsule = Sidekiq.default_configuration.default_capsule
      capsule.queues = ["default"]
      processor = Sidekiq::Processor.new(capsule) { nil }
      #{count + 1}.times do
        processor.send(:process_one) # private: the body of Processor#run's loop
      rescue StandardError => e
        puts "process_one: \#{e.class}: \#{e.message}"
      end

      Sidekiq.redis do |r|
        r.keys("executions:*").sort.each { |k| puts "\#{k}=\#{r.get(k)}" }
        puts "queue=\#{r.llen('queue:default')}"
        %w[retry schedule dead failed].each { |set| puts "\#{set}=\#{r.zcard(set)}" }
        r.zrange("retry", 0, -1).each { |j| puts "in_retry=\#{Sidekiq.load_json(j)['wrapped']}" }
        r.flushdb
      end
    RUBY
    assert_booted(output, status)
    skip "no Redis at #{REDIS_URL}" if output.include?("no-redis:")
    output
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

  KNOBS_SCRIPT = <<~'RUBY'.freeze
    puts "retry=#{Sidekiq.default_job_options['retry'].inspect}"
    puts "failures_max_count=#{Sidekiq.failures_max_count.inspect}"
  RUBY

  test "THECORE_JOB_RETRIES and THECORE_FAILED_JOBS_KEPT override the defaults; blank or 0 retries keep them off" do
    {
      { "THECORE_JOB_RETRIES" => "3", "THECORE_FAILED_JOBS_KEPT" => "5" } => ["3", "5"],
      { "THECORE_JOB_RETRIES" => "0", "THECORE_FAILED_JOBS_KEPT" => " 2 " } => ["false", "2"],
      { "THECORE_JOB_RETRIES" => "", "THECORE_FAILED_JOBS_KEPT" => "" } => ["false", "1"]
    }.each do |env, (retry_value, kept)|
      output, status = boot_as_sidekiq_server(KNOBS_SCRIPT, env)
      assert_booted(output, status)
      assert_match(/^retry=#{retry_value}$/, output, env.inspect)
      assert_match(/^failures_max_count=#{kept}$/, output, env.inspect)
    end
  end

  # A typo must never silently re-enable retries or keep every failed payload: the app refuses to boot.
  test "an invalid THECORE_JOB_RETRIES or THECORE_FAILED_JOBS_KEPT refuses to boot, naming the variable" do
    [
      ["THECORE_JOB_RETRIES", "yes"], ["THECORE_JOB_RETRIES", "-1"], ["THECORE_JOB_RETRIES", "1.5"],
      ["THECORE_FAILED_JOBS_KEPT", "0"], ["THECORE_FAILED_JOBS_KEPT", "all"]
    ].each do |variable, value|
      output, status = boot_as_sidekiq_server(KNOBS_SCRIPT, variable => value)
      assert_not status.success?, "#{variable}=#{value.inspect} booted:\n#{output}"
      assert_includes output, "#{variable}=#{value.inspect} is not valid"
      assert_includes output, "ThecoreBackendCommons::JobFailurePolicy::InvalidValue"
    end
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
    output, status = boot_as_sidekiq_server(<<~RUBY)
      Sidekiq.configure_server { |c| c.redis = { url: #{REDIS_URL.inspect} } }
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
    skip "no Redis at #{REDIS_URL}" if output.include?("no-redis:")
    assert_match(/^failed_count=1$/, output)
    assert_equal ["second-jid"], output.scan(/^failed_jid=(.*)$/).flatten
  end

  # A failing job runs exactly once: a plain ActiveJob and a mail job (ActionMailer::MailDeliveryJob),
  # processed the way a worker does. Afterwards nothing is waiting to run again: the queue, the retry
  # set, the schedule set and the Dead Set are empty, and the failures set holds at most one entry.
  test "by default a failing ActiveJob and a failing mail job each run exactly once and are never re-enqueued" do
    output = process_jobs_on_redis(<<~'RUBY', count: 2)
      class AlwaysFailingJob < ActiveJob::Base
        def perform(_payload)
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

      AlwaysFailingJob.set(queue: "default").perform_later("PAYLOAD")
      AlwaysFailingMailer.failing_email.deliver_later(queue: "default")
    RUBY

    %w[executions:job=1 executions:mail=1 queue=0 retry=0 schedule=0 dead=0].each do |line|
      assert_match(/^#{line}$/, output, output)
    end
    assert_operator output[/^failed=(\d+)$/, 1].to_i, :<=, 1, output
  end

  # The knob really works: with THECORE_JOB_RETRIES=1 a failed job waits in the retry set. A job's own
  # `sidekiq_options retry: false` still wins over it.
  test "THECORE_JOB_RETRIES=1 puts a failed job in the retry set, unless the job opts out" do
    output = process_jobs_on_redis(<<~'RUBY', count: 2, env: { "THECORE_JOB_RETRIES" => "1" })
      class RetriedJob < ActiveJob::Base
        def perform
          Sidekiq.redis { |r| r.incr("executions:retried") }
          raise "job failed"
        end
      end

      class OptedOutJob < ActiveJob::Base
        sidekiq_options retry: false

        def perform
          Sidekiq.redis { |r| r.incr("executions:opted_out") }
          raise "job failed"
        end
      end

      RetriedJob.set(queue: "default").perform_later
      OptedOutJob.set(queue: "default").perform_later
    RUBY

    %w[executions:retried=1 executions:opted_out=1 retry=1 in_retry=RetriedJob].each do |line|
      assert_match(/^#{line}$/, output, output)
    end
  end

  # Per-job override: `sidekiq_options retry: N` in an ActiveJob class wins over the default of none.
  test "an ActiveJob with its own sidekiq_options retry is retried despite the default" do
    output = process_jobs_on_redis(<<~'RUBY', count: 1)
      class SelfRetryingJob < ActiveJob::Base
        sidekiq_options retry: 1

        def perform
          Sidekiq.redis { |r| r.incr("executions:self_retrying") }
          raise "job failed"
        end
      end

      SelfRetryingJob.set(queue: "default").perform_later
    RUBY

    %w[executions:self_retrying=1 retry=1 in_retry=SelfRetryingJob].each do |line|
      assert_match(/^#{line}$/, output, output)
    end
  end
end
