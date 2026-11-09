# No background job is ever retried, app-wide (mailer jobs included). With `retry: false` Sidekiq 7
# keeps a failed job neither in the retry set nor in the Dead Set: it calls the death handlers and
# drops it. Retried jobs carrying large arguments (a PDF email holds the whole PDF) once filled a
# Thecore app's Redis to 23 GB until the host's OOM killer put it in a restart loop. A job that must
# be retried says so itself (`sidekiq_options retry: N`); a scheduled job just waits for its next tick.
# See docs/adr/0002-no-job-retries-failures-logged.md.
Sidekiq.default_job_options = { "retry" => false }

# Every failed job leaves a trace in the Rails log (ThecoreBackendCommons::DiscardedJobLogger: class or
# Mailer#action, queue, jid, error, never the arguments). Apps append their own handlers next to it.
# The handler is a plain require from lib/thecore_backend_commons.rb, not autoloaded: autoloaded
# constants aren't available to initializers, and configure_server only runs inside the Sidekiq
# process, so a missing constant would crash the worker at boot while every in-process test passed
# (test/initializers/sidekiq_server_boot_test.rb boots a server in a child process to catch it).
Sidekiq.configure_server do |config|
  config.death_handlers << ThecoreBackendCommons::DiscardedJobLogger unless config.death_handlers.include?(ThecoreBackendCommons::DiscardedJobLogger)
end
