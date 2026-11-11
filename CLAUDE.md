# CLAUDE.md — thecore_backend_commons

Rails engine gem providing shared backend utilities for the Thecore ecosystem: ActionCable channels, SMTP helpers, application record concerns, and Web Push notification infrastructure.
It is the generic base gem the rest of the ecosystem depends on (`model_driven_api`, `thecore_ui_rails_admin`, `mytask`, …), public on RubyGems: `.github/workflows/gempush.yml` publishes on a push to `release/3` only when `lib/*/version.rb` changes.

## Where things are

```
lib/thecore_backend_commons.rb   entry point: requires web-push, roo/roo-xls, smart_merge, JobFailurePolicy, DiscardedJobLogger
lib/thecore_backend_commons/     SmtpConfig, SmtpTester, PushNotificationService, DefaultModuleRegistry, JobFailurePolicy, DiscardedJobLogger
app/models/                      PushSubscriber, PushMessage, concerns/time_zone_aware.rb
app/channels/                    ActivityLogChannel, PushNotificationChannel
app/jobs/                        PushDispatchJob
app/mailers/concerns/            SmtpDeliverable
config/initializers/             application_config.rb (framework-imposed config), sidekiq.rb, concern_cable_connection.rb, default_module_registry.rb
db/migrate/                      push_subscribers / push_messages migrations
test/dummy/                      PostgreSQL dummy app
docs/adr/  GLOSSARY.md  docs/agents/
```

## Read before working on…

| Topic | File |
| --- | --- |
| Entry point, lib modules, mailer concerns, SMTP settings | `docs/agents/architecture.md` |
| Web Push: PushSubscriber/PushMessage, PushNotificationChannel, PushDispatchJob, PushNotificationService, VAPID, migrations | `docs/agents/web-push.md` |
| ActivityLogChannel, WebSocket connection authentication (JWT, m2m token) | `docs/agents/action-cable.md` |
| `TimeZoneAware` (`time_zone_aware` DSL) | `docs/agents/time-zone-aware.md` |
| `DefaultModuleRegistry` (default modules on every `ApplicationRecord` subclass) | `docs/agents/default-module-registry.md` |
| Framework-imposed host config, Sidekiq, no job retries, death handlers | `docs/agents/background-jobs.md` |
| ATOM isolation: what downstream gems inject, no upward references | `docs/agents/atom-isolation.md` |
| Dummy app, test DB, stubs, `config.assets` convention for consumers | `docs/agents/test-infrastructure.md` |
| CodeQL, secret scanning, Dependabot | `docs/agents/security-scanning.md` |
| Tickets (GitHub Issues), triage labels, glossary/ADR layout | `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md` |

When behaviour changes, update `CLAUDE.md` or the `docs/agents/` file it points to.

## Commands

```bash
# Run tests (from inside the submodule directory)
BUNDLE_GEMFILE=Gemfile RAILS_ENV=test bundle exec ruby -Itest -Ilib test/models/push_subscriber_test.rb

# Run all tests
BUNDLE_GEMFILE=Gemfile RAILS_ENV=test bundle exec ruby -Itest -Ilib -e "Dir['test/**/*_test.rb'].each { |f| require_relative f }"

# Bundle install
BUNDLE_GEMFILE=Gemfile bundle install

# One-time: create the Postgres test database (from test/dummy/)
BUNDLE_GEMFILE=../../Gemfile RAILS_ENV=test bundle exec bin/rails db:create
```

No need to unset `DATABASE_URL`: the dummy app's `config/boot.rb` rewrites its database name (see `docs/agents/test-infrastructure.md`).

## Rules

- **PostgreSQL only** for the dummy app and tests, never SQLite (this gem uses Postgres-specific SQL).
- **No dependency on `model_driven_api` or `rails_admin`**, and never reference `::ModelDrivenApi` (it depends on this gem): `json_attrs` composition uses `ThecoreBackendCommons.smart_merge`. API serialization and RailsAdmin config are injected by those gems (`docs/agents/atom-isolation.md`).
- Engine migration versions share one `schema_migrations` table across the whole host app, so they must be **globally unique**, not just unique within this gem.
- Constants used by initializers or `Sidekiq.configure_server` (`JobFailurePolicy`, `DiscardedJobLogger`) are plain `require`s from `lib/thecore_backend_commons.rb`, never autoloaded: a missing constant crashes only the worker.
- Job retries: off by default. An invalid `THECORE_JOB_RETRIES`/`THECORE_FAILED_JOBS_KEPT` must refuse to boot; `0` retries is `retry: false`, never `retry: 0`. Death handlers never log job arguments. Prefer `sidekiq_options retry: N` over ActiveJob's `retry_on` (`docs/agents/background-jobs.md`).
- `DefaultModuleRegistry` is installed from `config.to_prepare`, **not** `config.after_initialize` (which would miss eager-loaded subclasses in production).
- The WebSocket JWT signature is always verified (`docs/agents/action-cable.md`).
- **Regenerating VAPID keys invalidates all existing PushSubscribers** — browsers must re-subscribe.
- Consuming gems' dummy apps stub `config.assets`; do **not** add a real `sprockets-rails` dependency for it.
- Secret scanning push protection: if it fires on a real secret, remove it from the commit and rotate the secret; never bypass it.

## Agent skills

### Issue tracker

Tasks, issues, bugs, tickets and specs for this repository live **only** in its GitHub Issues
(`gabrieletassoni/thecore_backend_commons`), handled with the `gh` CLI. See `docs/agents/issue-tracker.md`.

**Mandatory rule.** Whenever a skill or development work creates, reads, updates, comments on,
assigns, blocks or closes a task, issue, bug, ticket or spec (for example /to-tickets, /to-spec,
/triage, /wayfinder, /implement, /diagnosing-bugs, /code-review, closing a piece of work, a bug found
during a session), do it in this repository's GitHub Issues following `docs/agents/issue-tracker.md`.
Never use Odoo, `.scratch/` or local Markdown files as a tracker: Odoo is only for the repositories
on Bancolini's GitLab. `#123` means a GitHub issue number of this repository. If `gh` doesn't work,
stop and say so instead of falling back to another tracker.

### Triage labels

The five canonical triage roles map to GitHub labels with the same name (`needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily when the first
term or decision is resolved. See `docs/agents/domain.md`.

### Skills

Matt Pocock's skills come from the `mattpocock-skills` Claude Code plugin installed on the
developer's **host** (`claude plugins install mattpocock-skills`, official marketplace), never
vendored here: no `.agents/skills/`, `.claude/commands/` or `skills-lock.json`. Its `ask-matt` skill
maps how the skills connect.
