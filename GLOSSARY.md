# Thecore Backend Commons

Shared Rails engine providing the backend infrastructure every Thecore app builds on: SMTP, ActionCable, Web Push, and — per this glossary — the runtime conventions Thecore apps don't get to individually reconsider.

## Language

**Framework-imposed convention**:
A runtime setting this gem configures unconditionally, on every app that depends on it, with no per-app opt-out. Justified when the setting only makes sense one way across the whole ecosystem, and precedent already exists: SMTP delivery method, ActionCable allowed origins, CORS policy, ActiveJob's queue adapter. Lives in `config/initializers/application_config.rb` (or a sibling initializer), never behind a `ThecoreSettings` toggle.
_Avoid_: default, override-able setting, opinionated default

**App-owned choice**:
A setting each Thecore app decides for itself — this gem neither sets it nor assumes a value. Everything not listed as a framework-imposed convention is this by default.
_Avoid_: app-level override, local config
