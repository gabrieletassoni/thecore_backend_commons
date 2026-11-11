# `ThecoreBackendCommons::DefaultModuleRegistry`

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (the default-module registry). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

Shared registry (ADR 0001/0002, `vendor/external/thecore/docs/adr/` in the host app) other gems use to register "default" modules that get `include`d automatically into every `ApplicationRecord` subclass **as it is defined**, instead of each gem independently overriding `inherited` or scanning `ApplicationRecord.subclasses` after boot (which misses classes not yet autoloaded in development).

```ruby
ThecoreBackendCommons::DefaultModuleRegistry.register(
  MyDefaultModule, # normally an ActiveSupport::Concern with an `included do ... end` block
  applies_to: ->(klass) { true } # optional; defaults to every subclass
)
```

Registered modules are `include`d, in registration order, into every `ApplicationRecord` subclass matching `applies_to`, at the moment the subclass is defined. `model_driven_api` and `thecore_ui_rails_admin` register their own default modules here (see ADR 0001) rather than each patching `ApplicationRecord.inherited` on their own — this gem is the shared hook point since it's the one the rest of the ecosystem already depends on. Both downstream registrations follow the exact same `config.to_prepare { DefaultModuleRegistry.register(...) }` shape as `default_module_registry.rb`'s own install, for the same eager-loading-ordering reason:

- `model_driven_api`'s `ModelDrivenApiDefaultJsonAttrs` (`config/initializers/default_json_attrs_registration.rb`) — gives every model a default `json_attrs = { except: [] }` with no explicit `Api::ModelName` concern required.
- `thecore_ui_rails_admin`'s `ThecoreUiRailsAdminDefaultNavigationConcern` (`config/initializers/concern_default_navigation.rb`) — gives every model a default RailsAdmin `navigation_label`/`navigation_icon` with no explicit `RailsAdmin::ModelName` concern required.

Both compose safely with an explicit per-model concern: since `ApplicationRecord.inherited` fires before the subclass's own body executes, the default is always applied first and a later `include Api::ModelName`/`RailsAdmin::ModelName` in the class body always runs after, freely overriding it.

- **Wiring**: `ThecoreBackendCommons::DefaultModuleRegistry::InheritedHook` is prepended onto `ApplicationRecord.singleton_class` (via `.install!`) from `config/initializers/default_module_registry.rb`, inside `config.to_prepare` — **not** `config.after_initialize`. Rails runs `to_prepare` callbacks *before* `eager_load!`, while `after_initialize` runs *after* it (`Rails::Application::Finisher`); installing from `after_initialize` would miss every subclass eager-loaded in production. `to_prepare` also re-runs on every class reload in development — `install!` is idempotent (checks the singleton-class ancestor chain before prepending).
- **`inherited` composition**: `InheritedHook#inherited` calls `super` first, then `DefaultModuleRegistry.apply_to(subclass)` — this both lets ActiveRecord's own `inherited` (STI `base_class` bookkeeping) run first, and composes correctly with any other gem's pre-existing `inherited` hook elsewhere in the singleton-class ancestor chain.
- **Idempotency**: registering the same module object twice is a no-op (the original registration/`applies_to` is kept). `apply_to` never re-`include`s a module a class already has in its ancestor chain, so STI subclasses inherit a default module from their base class rather than being separately (re-)included.
- **Abstract classes**: `apply_to` is a no-op for any class where `klass.abstract_class?` is true. `ApplicationRecord` itself (`primary_abstract_class`) never receives default modules through this mechanism at all, structurally — `ApplicationRecord.inherited` only fires for classes inheriting *from* `ApplicationRecord`, never for `ApplicationRecord`'s own definition. Note: because Ruby's `inherited` hook fires *before* the new subclass's own body executes, a class that sets `self.abstract_class = true` as a body statement (rather than being `primary_abstract_class`) may transiently see defaults applied to it before that assignment takes effect — a general Ruby ordering constraint, not something `apply_to` can detect synchronously.
- **Test helper**: `DefaultModuleRegistry.reset!` clears all registrations — not for production use.

See `test/lib/thecore_backend_commons/default_module_registry_test.rb` for coverage of registration/application order, `applies_to` filtering, abstract/STI exclusion, `super` composition, and double-registration.
