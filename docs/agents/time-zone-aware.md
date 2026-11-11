# Time-zone-aware datetime fields (`TimeZoneAware`)

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (the TimeZoneAware DSL). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

`app/models/concerns/time_zone_aware.rb` provides a class-level DSL, `time_zone_aware(*fields)`, that any model can call on its own UTC datetime fields to expose them three ways in JSON — the raw UTC instant, the same instant localized to the deployment-wide server time zone Setting, and localized to the record's own per-field time zone (falling back to the server Setting when unset). Implements the relevant part of `docs/adr/0009-timezone-aware-datetime-representation.md` (host repo).

This concern originated in the host app's `mytask` gem (a customer-specific "spot" gem) but was relocated here in `thecore_backend_commons` 3.6.0 when `PushMessage` (which lives in this gem) needed the same mechanism for its `sent_at`/`received_at`/`read_at` fields (issue #28, host repo) — `mytask` cannot be a dependency of this gem (wrong direction: this is the generic, ecosystem-wide base gem; `mytask` is IMAS/Bancolini-specific), so the DSL now lives at the lower, shared point in the dependency graph. `mytask` in turn gained a gemspec dependency on this gem (`~> 3.6`) and dropped its own copy, calling this one instead — its own model declarations (`Task`/`Project`/`TimeTable`/`Report`/etc.) are unchanged.

For each declared `field`:

- The migration must already have added a nullable `<field>_time_zone` string column.
- A `validate` rejects a non-blank `<field>_time_zone` that isn't a valid IANA identifier (via `ActiveSupport::TimeZone[value]`).
- Two instance methods are defined: `<field>_server_tz` and `<field>_record_tz` (see above).
- Both are merged into the model's `json_attrs[:methods]` via `ThecoreBackendCommons.smart_merge` (defined in `lib/thecore_backend_commons.rb`, `deep_merge`-based) — same as `BaseApplicationRecordConcern` (see `docs/agents/atom-isolation.md`). Until 3.8.0 both called `::ModelDrivenApi.smart_merge`, an upward reference to a gem that depends on this one, which crashed with `NameError` in any app without `model_driven_api` (the dummy app hid it with a stub whose shallow-merge semantics even differed from the real one). `ModelDrivenApi.smart_merge` now delegates here; covered by `test/lib/smart_merge_test.rb`, and the dummy app has no stub any more.
- `TimeZoneAware.localize`/`.server_time_zone` are NULL-safe: a `nil` field value returns `nil`; a blank/invalid/absent zone returns the bare UTC value unshifted.

Declared on: `PushMessage`'s `sent_at`/`received_at`/`read_at` (this gem). `mytask` declares it on `Task`/`Project`, `TimeTable`/`FreeTimeTable`, `Report`/`FreeReport`, `Assignment`, `Milestone`, `Unavailability` — see that gem's own CLAUDE.md.

Test coverage: `test/models/push_message_test.rb`'s "time-zone awareness" section — record zone present/different from server, `NULL` fallback, invalid zone rejected.
