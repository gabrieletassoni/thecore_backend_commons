# Test infrastructure

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (the PostgreSQL dummy app, its stubs, the config.assets convention). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

The dummy app (`test/dummy/`) runs on **PostgreSQL only** — like every Thecore gem and host app (this gem uses Postgres-specific SQL; never SQLite). `test/dummy/config/database.yml` uses `adapter: postgresql` (host/port/user/password from `PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD`, defaulting to `db`/`5432`/`postgres`/`postgres`) with databases `thecore_backend_commons_{development,test,production}`. Because `DATABASE_URL` overrides `database.yml` and the devcontainer points it at the host app's dev DB (which the schema load, `force: :cascade`, or `db:test:prepare` would clobber), `test/dummy/config/boot.rb` keeps `DATABASE_URL`'s server/credentials but swaps its database name to `thecore_backend_commons_<RAILS_ENV>` — done in boot.rb rather than the test helper so every entry point (`bin/rails db:*`, Rails' `db:test:prepare` subprocess) is covered. Create the test DB once with `RAILS_ENV=test bin/rails db:create` (see Commands in `CLAUDE.md`). Key stubs in `test/dummy/config/application.rb`:
- `ModelDrivenApi.smart_merge` stub (model_driven_api not in bundle)
- `config.action_mailbox` stub (not in rails/all)
- `config.assets` stub (sprockets not in bundle)
- `User`, `Ability`, `ApplicationCable::Connection` preloaded before `run_load_hooks`
- `has_rich_text` stubbed via `ActiveSupport.on_load(:active_record)`

**Convention for any gem consuming this one**: `config/initializers/application_config.rb` unconditionally sets `config.assets.prefix` at boot — every downstream gem's own dummy test app hits this the moment it eager-loads far enough to run this initializer, since `config.assets` doesn't exist unless a Sprockets/Propshaft railtie is loaded. Do **not** add a real `sprockets-rails` dependency just to satisfy this one line — stub `config.assets` the same way this file and `thecore_ui_rails_admin`'s dummy app do (a `method_missing`-based stub prepended onto `Rails::Application::Configuration`). Confirmed working in `thecore_download_documents` and `thecore-spot-overrides`'s own dummy apps.
