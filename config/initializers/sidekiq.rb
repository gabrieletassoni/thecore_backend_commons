# What a failed background job leaves behind, app-wide, from the container's environment:
# THECORE_JOB_RETRIES (default 0, no retries) and THECORE_FAILED_JOBS_KEPT (default 1, the latest
# failure in the sidekiq-failures set); an invalid value refuses to boot (JobFailurePolicy).
# Why: docs/adr/0002-no-job-retries-failures-logged.md.
ThecoreBackendCommons::JobFailurePolicy.apply!

# Every failed job leaves one line in the Rails log (DiscardedJobLogger); apps append their own
# handlers next to it. Required, not autoloaded: see docs/adr/0002-no-job-retries-failures-logged.md.
Sidekiq.configure_server do |config|
  config.death_handlers << ThecoreBackendCommons::DiscardedJobLogger unless config.death_handlers.include?(ThecoreBackendCommons::DiscardedJobLogger)
end
