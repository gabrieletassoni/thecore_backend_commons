# What a failed background job leaves behind, app-wide (ThecoreBackendCommons::JobFailurePolicy, read
# from the container's environment; an invalid value refuses to boot):
# - no retries (THECORE_JOB_RETRIES, default 0, i.e. `retry: false`): Sidekiq 7 then keeps a failed
#   job neither in the retry set nor in the Dead Set, it calls the death handlers and drops it.
#   Retried jobs carrying large arguments (a PDF email holds the whole PDF) once filled a Thecore
#   app's Redis to 23 GB until the host's OOM killer put it in a restart loop. A job that must be
#   retried says so itself (`sidekiq_options retry: N`); a scheduled job just waits for its next tick.
# - one failed job kept (THECORE_FAILED_JOBS_KEPT, default 1): sidekiq-failures (required by
#   thecore_background_jobs) stores each failed job's full payload, arguments included, in the Redis
#   `failed` set and trims it to the last Sidekiq.failures_max_count (its own default 1000: up to
#   1000 PDF-sized copies). The Failures tab still shows the latest failure.
# See docs/adr/0002-no-job-retries-failures-logged.md.
ThecoreBackendCommons::JobFailurePolicy.apply!

# Every failed job leaves a trace in the Rails log (ThecoreBackendCommons::DiscardedJobLogger: class or
# Mailer#action, queue, jid, error, never the arguments). Apps append their own handlers next to it.
# The handler is a plain require from lib/thecore_backend_commons.rb, not autoloaded: autoloaded
# constants aren't available to initializers, and configure_server only runs inside the Sidekiq
# process, so a missing constant would crash the worker at boot while every in-process test passed
# (test/initializers/sidekiq_server_boot_test.rb boots a server in a child process to catch it).
Sidekiq.configure_server do |config|
  config.death_handlers << ThecoreBackendCommons::DiscardedJobLogger unless config.death_handlers.include?(ThecoreBackendCommons::DiscardedJobLogger)
end
