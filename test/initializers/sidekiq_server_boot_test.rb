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

  test "the app boots as a Sidekiq server with job retries off and the generic death handler registered once" do
    output, status = boot_as_sidekiq_server(<<~'RUBY')
      puts "retry=#{Sidekiq.default_job_options['retry'].inspect}"
      puts "handlers=#{Sidekiq.default_configuration.death_handlers.map(&:to_s).inspect}"
    RUBY

    assert_booted(output, status)
    assert_match(/^retry=false$/, output)
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
end
