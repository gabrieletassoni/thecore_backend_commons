# No background job is retried; every failure is logged

**Status**: accepted

In a Thecore app in production (`mytask-imas`, its ADR 0029), Redis grew to 23 GB until the host's OOM killer put it in a restart loop and no job ran for three days. The payloads were mail jobs carrying a whole PDF in their arguments. They used Sidekiq's default `retry: true`: a failing one stayed in the retry set for 25 attempts over about 21 days, then in the Dead Set, which is capped by count and age but not by size. Almost all had failed with a permanent SMTP error that no retry could fix, and nothing in the app showed it. That app fixed it for itself; every other Thecore app was still born with retries on.

With `retry: false`, Sidekiq 7 keeps a failed job neither in the retry set nor in the Dead Set: `Sidekiq::JobRetry#global` calls the death handlers and drops the job.

**Decision**: this gem, which already imposes Sidekiq as the production queue adapter (ADR 0001), also imposes `Sidekiq.default_job_options = { "retry" => false }` (`config/initializers/sidekiq.rb`), a framework-imposed convention (`GLOSSARY.md`). It registers a generic death handler, `ThecoreBackendCommons::DiscardedJobLogger`, that writes one Rails log line per failure: job class (or `Mailer#action` for a mail job), queue, jid and error, never the arguments. The handler is a plain `require` from `lib/thecore_backend_commons.rb`: an autoloaded constant isn't available to initializers, and `configure_server` runs only inside the Sidekiq process, so a mistake there crashes the worker at boot while the web process and every in-process test stay green (as happened to the pilot).

Apps add their own handlers next to it (`config.death_handlers << MyHandler` in their own `Sidekiq.configure_server`), for instance to record failures somewhere their users look. The pilot keeps its `JobFailureLog`, which writes an `IntegrationLog`: engine initializers run before the app's, so the handlers are `[DiscardedJobLogger, JobFailureLog]` and both run; its own `retry: false` line sets the same value again.

## Considered Options

- **Leave retries on and only document the risk.** Rejected: the pilot's incident is exactly a convention nobody remembered.
- **Record failures in a model of this gem.** Rejected: apps already have their own place for errors (the pilot's `IntegrationLog`), and a generic table nobody reads would hide failures as well as the Dead Set did. The Rails log is the one place every app has.

## Consequences

- A job that should be retried must say so itself (`sidekiq_options retry: N`). A scheduled job simply runs again at its next tick.
- Failed jobs no longer appear in Sidekiq's Retries or Dead tabs.
- **At most one failed job stays in Redis.** `sidekiq-failures` 1.1.0, required by `thecore_background_jobs`, runs as server middleware in `:all` mode and stores every failed job's full payload, arguments included, in the Redis `failed` sorted set, then trims it to the last `Sidekiq.failures_max_count` (default 1000: up to 1000 PDF-sized copies even with no retries). The same initializer sets `Sidekiq.failures_max_count = 1` (decided by the product owner, 2026-11-09): the Failures tab of `thecore_background_jobs` still shows the latest failure, Redis holds at most one payload, and every failure still reaches the death handlers. Turning `sidekiq-failures` off (`failures_default_mode = :off`) was rejected because it would leave that tab always empty.
- Covered by `test/initializers/sidekiq_server_boot_test.rb`, which boots the dummy app as a Sidekiq server in a child process, checks `retry` and `failures_max_count`, runs a failing mail job through Sidekiq's real `JobRetry`, and runs two failing jobs through the server middleware chain against a real Redis (`REDIS_URL`, skipped when unreachable) to check that only the latest stays in `failed`. A last test, also on a real Redis, enqueues a failing plain ActiveJob and a failing `ActionMailer::MailDeliveryJob` through the Sidekiq adapter and processes them with Sidekiq's own `Processor` (fetch, server middleware, `JobRetry`), the path a worker takes: each runs exactly once (the product owner's requirement: zero retries, never more than one execution), and afterwards the queue, the retry set, the schedule set and the Dead Set are empty and `failed` holds at most one entry. With `retry` back on it fails on the retry set.
