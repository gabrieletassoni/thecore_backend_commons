# Architecture

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (entry point, mailer concerns, lib modules, SMTP settings). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Entry point

`lib/thecore_backend_commons.rb` — requires all dependencies including `web-push` (for VAPID push notifications) and `roo`/`roo-xls` (spreadsheet import, used by the spot items importer). roo is `~> 3.0` since 3.9.0 so the bundle can take rubyzip >= 3.4 (CVE-2026-85396); roo 4 waits for a roo-xls that allows it. `test/lib/spreadsheet_import_test.rb` checks `.xlsx`/`.xls` parsing.

## Mailer concerns

**`SmtpDeliverable`** (`app/mailers/concerns/smtp_deliverable.rb`):
Include in ActionMailer subclasses to configure SMTP from `ThecoreSettings` at send time (no restart needed).

## Lib

**`ThecoreBackendCommons::SmtpConfig`** — reads SMTP settings from `ThecoreSettings` (ns: `:smtp`).
**`ThecoreBackendCommons::SmtpTester`** — sends a test email; callable via `SmtpTester.call("me@example.com")`.
**`ThecoreBackendCommons::DiscardedJobLogger`** — generic Sidekiq death handler, see `docs/agents/background-jobs.md`.
**`ThecoreBackendCommons::JobFailurePolicy`** — reads `THECORE_JOB_RETRIES`/`THECORE_FAILED_JOBS_KEPT`, see `docs/agents/background-jobs.md`.
## SMTP settings (ns: `:smtp`)

`address`, `port`, `domain`, `user_name`, `password`, `authentication`, `enable_starttls_auto`, `from`, `delivery_method`
