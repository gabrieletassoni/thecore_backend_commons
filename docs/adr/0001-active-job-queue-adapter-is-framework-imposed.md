# ActiveJob's queue adapter is a framework-imposed convention, not an app choice

**Status**: accepted

A host app (`mytask-imas`) shipped for weeks with `config.active_job.queue_adapter` never set anywhere, silently defaulting to Rails' in-process `:async` adapter, despite always running a dedicated Sidekiq worker service. `:async` doesn't persist jobs — anything in flight was lost on every process restart, with no retry and no visibility — and the bug was invisible until a `SystemStackError`, unrelated in origin, briefly put it under a microscope. Fixing it app-by-app punts the same mistake to the next app scaffolded the same way.

We looked for precedent before deciding this belonged here rather than being asked, per-app, again. `config/initializers/application_config.rb` already imposes several settings on every consuming app unconditionally, no opt-out: `config.action_mailer.delivery_method = :smtp`, `config.action_cable.allowed_request_origins` (wide-open, matching any scheme), `config.relative_url_root`, `config.active_storage`'s disk config. `thecore_ui_commons` does the same for `config.filter_parameters`. `model_driven_api` inserts `Rack::Cors` with `origins '*'` unconditionally — a materially more consequential imposition (security posture, not just infra wiring) than queue routing. This is the established shape of the ecosystem, not an exception we'd be introducing.

`thecore_background_jobs` (a transitive dependency of this gem) goes further still: it already hard-`require`s `sidekiq`/`sidekiq-scheduler`/`sidekiq-failures` and unconditionally mounts `Sidekiq::Web` at `/sidekiq` in its own routes, and sets several ActiveJob-queue-adjacent settings (`deliver_later_queue_name`, ActiveStorage/ActionMailbox queue names). Every consumer of this gem was already committed to running Sidekiq before this change — `queue_adapter` was the one missing line that made none of that infrastructure actually get used.

We therefore add `Rails.application.config.active_job.queue_adapter = :sidekiq` to `application_config.rb`, guarded by `Rails.env.production?` only — development and test stay on `:async`, since neither should require a reachable Redis, and forcing real Sidekiq into test suites changes how job assertions have to be written for every consumer, which is a much bigger and more disruptive imposition than this ADR is trying to make. See `CONTEXT.md` for the general "framework-imposed convention vs. app-owned choice" vocabulary this decision instantiates.

## Considered Options

- **A boot-time check that verifies Redis/Sidekiq reachability before switching the adapter, failing loudly if absent.** Rejected: the contract is documentary, not defensive — "depend on this gem, run a worker" — matching how every other imposed setting in this file already works (none of them runtime-verify their own precondition either, e.g. nothing checks an SMTP server is reachable before setting `delivery_method = :smtp`).
- **Leave it as an app-level setting, just document the convention.** Rejected: this is exactly the shape of the bug that prompted the investigation — a convention that's easy to forget precisely because nothing enforces it, discovered only when a production incident forced a closer look.

## Consequences

- Any app depending on this gem (`~> 3.6` or later, per the minor version bump that ships this) gets real Sidekiq-backed job persistence in production the moment it upgrades, with no app-level change required — including apps we don't know about, since this gem is public on RubyGems.org (56k+ downloads at time of writing).
- An app that deliberately wants a different production queue backend must now override `config.active_job.queue_adapter` explicitly, after this initializer runs, rather than simply never setting it.
- An app whose own job/mailer call sites pass non-JSON-serializable arguments to `deliver_later`/`perform_later` (raw binary strings, for instance) will start failing loudly at enqueue time on upgrade, where it previously failed silently or worked by accident under `:async`'s in-memory hand-off. This is a real, separate risk this ADR does not mitigate — see `mytask-imas`'s own `docs/adr/0017-active-job-queue-adapter-sidekiq.md` for the shape of that failure and its fix; each app upgrading must audit its own call sites the same way.
