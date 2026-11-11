# Framework-imposed config and background jobs

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (framework-imposed host app config, no job retries by default). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Framework-imposed host app config (`config/initializers/application_config.rb`)

Settings this gem sets unconditionally on every consuming app, with no per-app opt-out — see `GLOSSARY.md` for the "framework-imposed convention vs. app-owned choice" vocabulary and `docs/adr/0001-active-job-queue-adapter-is-framework-imposed.md` for the reasoning and full precedent list: `config.relative_url_root`, `config.assets.prefix`, `config.active_storage` disk config, `config.action_mailer.delivery_method = :smtp`, `config.action_cable.allowed_request_origins`, and — production only — `config.active_job.queue_adapter = :sidekiq` (development/test stay on Rails' `:async` default). An app that genuinely needs a different production queue adapter must override it explicitly, after this initializer runs.

### No job retries by default (`config/initializers/sidekiq.rb`)

`ThecoreBackendCommons::JobFailurePolicy.apply!` (`lib/thecore_backend_commons/job_failure_policy.rb`, a plain `require`) sets, on every app, mailer jobs included:

- **no retries**: `Sidekiq.default_job_options["retry"] = false`. Sidekiq 7 then keeps a failed job in neither the retry set nor the Dead Set: it calls the death handlers and drops the job. Retried mail jobs carrying a whole PDF once filled a Thecore app's Redis to 23 GB (`docs/adr/0002-no-job-retries-failures-logged.md`).
- **one failed job kept**: `Sidekiq.failures_max_count = 1`. `sidekiq-failures` (from `thecore_background_jobs`) stores each failed job's full payload, arguments included, in the Redis `failed` set and trims it to that count after each failure (its own default is 1000). The latest failure stays visible in the Failures tab.

Each installation can change them from the container environment (`backend` and `worker` alike; on a `thecore_devcontainer` deploy, the target's `vendor/deploytargets/<provider>/<customer>.env`, passed through by `env_file`, that repo's ADR 0002):

| Variable | Unset/blank | Valid | Effect |
| --- | --- | --- | --- |
| `THECORE_JOB_RETRIES` | `0` (`retry: false`) | whole number >= 0 | app-wide Sidekiq retry count |
| `THECORE_FAILED_JOBS_KEPT` | `1` | whole number >= 1 | `Sidekiq.failures_max_count` |

Anything else raises `JobFailurePolicy::InvalidValue` and the app refuses to boot: a typo must never silently re-enable retries. `0` retries becomes `false`, never `retry: 0` (which still sends exhausted jobs to the Dead Set). A job class overrides the count for itself with `sidekiq_options retry: N` / `retry: false` (works on ActiveJob classes, wins both ways). **ActiveJob's `retry_on` is outside all of this**: it re-enqueues a new copy of the job, arguments included, whatever `THECORE_JOB_RETRIES` says; prefer `sidekiq_options retry: N`.

Inside `Sidekiq.configure_server` it registers `ThecoreBackendCommons::DiscardedJobLogger` (`lib/thecore_backend_commons/discarded_job_logger.rb`) as death handler, once: one Rails log line per failure with no retry left, with the job class (or `Mailer#action`), queue, jid and error, **never the arguments**. Both are plain `require`s from `lib/thecore_backend_commons.rb`, never autoloaded: autoloaded constants aren't available to initializers and `configure_server` only runs inside the Sidekiq process, so a missing constant crashes only the worker. Apps append their own handlers in their own initializer (`config.death_handlers << MyHandler`); engine initializers run first, so both run. `mytask-imas` keeps its `JobFailureLog` (writes `IntegrationLog`) this way.

Test: `test/initializers/sidekiq_server_boot_test.rb` boots the dummy app as a Sidekiq server in a child process, as `Sidekiq::CLI` does (`sidekiq/rails` required before the app, so `configure_server` and the ActiveJob integration run). It checks the defaults, valid and invalid values of both variables (invalid ones must refuse to boot), and a failing mail job through the real `JobRetry#global` (log line without arguments; no Redis needed). On a real Redis (`REDIS_URL`, e.g. `redis://redis:6379/15`; skipped when unreachable) it checks: two failures leave only the latest in `failed`; a failing ActiveJob and a failing `ActionMailer::MailDeliveryJob` processed by Sidekiq's real `Processor` run exactly once and leave nothing in the queue, `retry`, `schedule` or `dead`; `THECORE_JOB_RETRIES=1` puts a failed job in the retry set unless it has `sidekiq_options retry: false`; and `sidekiq_options retry: 1` on an ActiveJob wins over the default.
