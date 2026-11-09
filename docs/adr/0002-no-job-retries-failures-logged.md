# No background job is retried by default; every failure is logged

**Status**: accepted

In a Thecore app in production (`mytask-imas`, its ADR 0029), Redis grew to 23 GB until the host's OOM killer put it in a restart loop and no job ran for three days. The payloads were mail jobs carrying a whole PDF in their arguments. They used Sidekiq's default `retry: true`: a failing one stayed in the retry set for 25 attempts over about 21 days, then in the Dead Set, which is capped by count and age but not by size. Almost all had failed with a permanent SMTP error that no retry could fix, and nothing in the app showed it. That app fixed it for itself; every other Thecore app was still born with retries on.

With `retry: false`, Sidekiq 7 keeps a failed job neither in the retry set nor in the Dead Set: `Sidekiq::JobRetry#global` calls the death handlers and drops the job.

**Decision**: this gem, which already imposes Sidekiq as the production queue adapter (ADR 0001), also sets `Sidekiq.default_job_options["retry"] = false` (`config/initializers/sidekiq.rb`, through `ThecoreBackendCommons::JobFailurePolicy`) on every app, and caps the failures set at one job (below). Both are defaults an installation can change from its environment, never silently: see "Overriding the defaults". It registers a generic death handler, `ThecoreBackendCommons::DiscardedJobLogger`, that writes one Rails log line per failure: job class (or `Mailer#action` for a mail job), queue, jid and error, never the arguments. The handler is a plain `require` from `lib/thecore_backend_commons.rb`: an autoloaded constant isn't available to initializers, and `configure_server` runs only inside the Sidekiq process, so a mistake there crashes the worker at boot while the web process and every in-process test stay green (as happened to the pilot).

Apps add their own handlers next to it (`config.death_handlers << MyHandler` in their own `Sidekiq.configure_server`), for instance to record failures somewhere their users look. The pilot keeps its `JobFailureLog`, which writes an `IntegrationLog`: engine initializers run before the app's, so the handlers are `[DiscardedJobLogger, JobFailureLog]` and both run; its own `retry: false` line sets the same value again.

## Overriding the defaults

Decided by the product owner, 2026-11-09: the defaults stay, but each installation can change them. `ThecoreBackendCommons::JobFailurePolicy` (`lib/thecore_backend_commons/job_failure_policy.rb`, a plain `require`) reads two variables from the container's environment at boot:

| Variable | Unset or blank | Valid value | Sets |
| --- | --- | --- | --- |
| `THECORE_JOB_RETRIES` | `0`: `retry: false` | a whole number N >= 0 (`0` is the same as unset) | `Sidekiq.default_job_options["retry"] = N` |
| `THECORE_FAILED_JOBS_KEPT` | `1` | a whole number N >= 1 | `Sidekiq.failures_max_count = N` |

Any other value (`yes`, `-1`, `1.5`, `0` for the second) raises `JobFailurePolicy::InvalidValue`, naming the variable and the value, and the app refuses to boot, web and worker alike: a typo must never silently turn retries back on or keep every failed payload. It is the same pattern as the pilot's `GAMMA_INTEGRATION` (its ADR 0031). Zero retries maps to `false`, not `0`: with `retry: 0` Sidekiq still sends an exhausted job to the Dead Set.

Where to set them: in the environment of the `backend` and `worker` containers. On an installation deployed by `thecore_devcontainer`, that is the target's `vendor/deploytargets/<provider>/<customer>.env`, which reaches both containers through their `env_file` (`thecore_devcontainer` ADR 0002); on a hand-written compose, its `environment:`. Both containers need the same value, so the setting a web process enqueues with is the one the worker runs with.

A job class still overrides the retry count for itself with Sidekiq's own `sidekiq_options retry: N` (or `retry: false`), which wins over the app-wide default in both directions. It works on ActiveJob classes: `sidekiq/rails` adds `sidekiq_options` to `ActiveJob::Base`.

ActiveJob's own `retry_on` in a job class is a different mechanism, outside all of this: on failure ActiveJob enqueues a new copy of the job itself (into Sidekiq's schedule set when there is a wait), so the job is retried whatever `THECORE_JOB_RETRIES` says, and each copy carries the full arguments again. Don't use `retry_on` on a job with large arguments; use `sidekiq_options retry: N` instead, which this default and the death handlers see.

## Considered Options

- **Leave retries on and only document the risk.** Rejected: the pilot's incident is exactly a convention nobody remembered.
- **Settings (`ThecoreSettings`) instead of environment variables.** Rejected: restoring a production dump on a test installation would carry its value with it, and the value is needed at boot, before an admin could look at it.
- **Record failures in a model of this gem.** Rejected: apps already have their own place for errors (the pilot's `IntegrationLog`), and a generic table nobody reads would hide failures as well as the Dead Set did. The Rails log is the one place every app has.

## Consequences

- A job that should be retried must say so itself (`sidekiq_options retry: N`), or the installation sets `THECORE_JOB_RETRIES`. A scheduled job simply runs again at its next tick.
- With the default, failed jobs no longer appear in Sidekiq's Retries or Dead tabs. With `THECORE_JOB_RETRIES` > 0 they do again, and an exhausted job ends in the Dead Set, capped by count and age but not by size: the risk this ADR removes comes back, and it is the installation's choice. The death handlers run once a job has no retry left, so the log line comes then.
- **At most one failed job stays in Redis.** `sidekiq-failures` 1.1.0, required by `thecore_background_jobs`, runs as server middleware in `:all` mode and stores every failed job's full payload, arguments included, in the Redis `failed` sorted set, then trims it to the last `Sidekiq.failures_max_count` (default 1000: up to 1000 PDF-sized copies even with no retries). The same initializer sets `Sidekiq.failures_max_count = 1` by default (decided by the product owner, 2026-11-09; `THECORE_FAILED_JOBS_KEPT` changes it): the Failures tab of `thecore_background_jobs` still shows the latest failure, Redis holds at most one payload, and every failure still reaches the death handlers. Turning `sidekiq-failures` off (`failures_default_mode = :off`) was rejected because it would leave that tab always empty.
- Covered by `test/initializers/sidekiq_server_boot_test.rb`, which boots the dummy app as a Sidekiq server in a child process, the way `Sidekiq::CLI` does (`sidekiq/rails` before the app):
  - the defaults (`retry` false, `failures_max_count` 1, the death handler registered once), valid values of both variables (`3`/`5`, `0`/` 2 `, blank), and invalid ones (`yes`, `-1`, `1.5`; `0`, `all`), which must refuse to boot naming the variable;
  - a failing mail job through Sidekiq's real `JobRetry`, logged without its arguments;
  - on a real Redis (`REDIS_URL`, skipped when unreachable): two failing jobs through the server middleware leave only the latest in `failed`; a failing plain ActiveJob and a failing `ActionMailer::MailDeliveryJob`, enqueued through the Sidekiq adapter and processed by Sidekiq's own `Processor`, each run exactly once (the product owner's requirement: zero retries, never more than one execution) and leave the queue, the retry, schedule and dead sets empty with at most one entry in `failed`; with `THECORE_JOB_RETRIES=1` a failed job waits in the retry set while one with `sidekiq_options retry: false` does not; and with the default an ActiveJob with `sidekiq_options retry: 1` does wait in the retry set.
