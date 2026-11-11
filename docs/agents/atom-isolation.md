# ATOM isolation principle

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (what this gem owns, what downstream gems inject, no upward references). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

`thecore_backend_commons` owns only core domain logic (models, channels, services). It has **no dependency** on `model_driven_api` or `rails_admin`. API serialization (`json_attrs`) and RailsAdmin configuration for `PushSubscriber` and `PushMessage` are injected by downstream gems via `after_initialize`:

| Gem | What it injects | Where |
|-----|----------------|-------|
| `model_driven_api` | `ModelDrivenApiPushSubscriber` / `ModelDrivenApiPushMessage` (json_attrs) | `config/initializers/after_initialize_for_model_driven_api.rb` |
| `thecore_ui_rails_admin` | `ThecoreUiRailsAdminPushSubscriberConcern` / `ThecoreUiRailsAdminPushMessageConcern` (rails_admin) | `config/initializers/after_initialize.rb` |

`name` and `surname` are included in `only:` for the user/sender serialization — Rails `as_json` silently omits columns that don't exist on the model, so the serialization is safe across all environments.

**No upward references**: this gem never references `::ModelDrivenApi` (which depends on it). `json_attrs` composition uses this gem's own `ThecoreBackendCommons.smart_merge`; `ModelDrivenApi.smart_merge` delegates to it. Before 3.8.0 `BaseApplicationRecordConcern` and `TimeZoneAware` called `::ModelDrivenApi.smart_merge` directly, so a host/dummy app without `model_driven_api` failed model boot with `NameError` unless it defined a stub.
