This is part of [Thecore framework](https://github.com/gabrieletassoni/thecore/tree/release/3).

---

## Web Push notifications (VAPID)

Self-contained browser push notifications — no Firebase, no APNs, no third-party account required. The gem provides the server-side half: models, dispatch service, and ActionCable channel. The client integration guide (React + service worker) lives in the [`model_driven_api` README](../model_driven_api/README.md#web-push-vapid-from-a-react-client).

### How it works

```
Browser                   Rails backend
  │                            │
  │── POST subscribe ─────────►│  PushSubscriber.subscribe_for(user, endpoint:, p256dh:, auth:)
  │                            │
  │◄─ ActionCable stream ──────│  PushNotificationChannel streams push_notifications_subscriber_N
  │                            │
  │  [backend sends push]      │  PushNotificationService.dispatch(subscriber, message)
  │◄─ Web Push payload ────────│    → Webpush.payload_send (VAPID)
  │                            │    → message.sent_at = now
  │── POST acknowledge ────────►│  message.update!(received_at: / read_at:)
```

### Server configuration

VAPID keys are generated automatically the first time `rails db:seed` runs. You only need to set the contact email via RailsAdmin → Settings:

| ThecoreSettings key (`ns: :vapid`) | Purpose | Default |
|------------------------------------|---------|---------|
| `public_key` | VAPID public key (base64url) — send to browsers | generated at seed |
| `private_key` | VAPID private key — never expose to clients | generated at seed |
| `contact_email` | `mailto:` URI in VAPID `sub` claim | `""` (set this) |
| `max_messages_per_subscriber` | PushMessage retention cap per subscriber | `"500"` |

> **Regenerating VAPID keys invalidates all existing `PushSubscriber` records.** Every registered browser must re-subscribe.

### Models

#### `PushSubscriber`

Represents one browser/device subscription registered by a `User`.

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | bigint | FK to users |
| `endpoint` | text | Unique; push service URL provided by the browser |
| `p256dh` | string | ECDH public key (base64url) |
| `auth` | string | Auth secret (base64url) |
| `user_agent` | string | Browser/OS identifier |
| `expired_at` | datetime | `nil` = active; set when the push service returns 410 |

```ruby
# Upsert by endpoint (re-registering an existing browser updates the record)
PushSubscriber.subscribe_for(user, endpoint:, p256dh:, auth:, user_agent:)

# Scope: only active (not expired)
PushSubscriber.active

# Expire a subscriber (called automatically on 410 from push service)
subscriber.expire!
```

#### `PushMessage`

Records a notification payload and its lifecycle.

| Column | Type | Notes |
|--------|------|-------|
| `push_subscriber_id` | bigint | FK |
| `title` | string | Required |
| `body` | text | Required |
| `url` | string | URL to open on notification click (optional) |
| `icon` | string | Notification icon URL (optional) |
| `sent_at` | datetime | Populated by `PushNotificationService` on successful dispatch |
| `received_at` | datetime | Set by client via `acknowledge` endpoint |
| `read_at` | datetime | Set by client via `acknowledge` endpoint |

Old messages beyond `vapid.max_messages_per_subscriber` are pruned automatically after each dispatch (oldest first).

### `PushNotificationService`

```ruby
ThecoreBackendCommons::PushNotificationService.dispatch(subscriber, message)
```

1. Calls `Webpush.payload_send` with the subscriber's keys and the VAPID credentials from `ThecoreSettings`.
2. On success: sets `message.sent_at = Time.current`.
3. On `Webpush::ExpiredSubscription` or `Webpush::InvalidSubscription` (HTTP 410/404 from push service): calls `subscriber.expire!`.
4. Prunes oldest `PushMessage` records if the subscriber exceeds the retention cap.
5. Always returns `message` — errors are rescued and logged, never propagated.

### `PushNotificationChannel` (ActionCable)

```ruby
# In your connection.rb — current_user must be set
class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user
  # ... authenticate and set current_user
end
```

Subscribe from the frontend:

```javascript
// Stream for one subscriber (most common)
consumer.subscriptions.create(
  { channel: "PushNotificationChannel", subscriber_id: subscriberId },
  { received(data) { /* handle message */ } }
);

// Stream for all active subscribers of the current user
consumer.subscriptions.create(
  { channel: "PushNotificationChannel", user_id: currentUserId },
  { received(data) { /* handle message */ } }
);
```

The channel only streams to `subscriber_id` values that belong to `current_user` — unauthorized subscriber IDs are silently ignored.

Broadcast from anywhere in the backend:

```ruby
PushNotificationChannel.broadcast_to(subscriber, message)
# Sends message.as_json to "push_notifications_subscriber_#{subscriber.id}"
```

---

## `DefaultModuleRegistry` — shared `ApplicationRecord.inherited` hook

Other gems in the ecosystem (`model_driven_api`, `thecore_ui_rails_admin`, ...) need to give
*every* model some default behavior — a default API serialization shape, a default RailsAdmin
navigation entry — without requiring a generated per-model concern file for the
no-customization case. Rather than each gem independently overriding
`ApplicationRecord.inherited` (and risking one override clobbering another), they all register
into this one shared registry:

```ruby
ThecoreBackendCommons::DefaultModuleRegistry.register(
  MyDefaultModule, # normally an ActiveSupport::Concern with an `included do ... end` block
  applies_to: ->(klass) { true } # optional; defaults to every ApplicationRecord subclass
)
```

Every registered module is `include`d, in registration order, into every `ApplicationRecord`
subclass for which `applies_to` returns true — at the moment the subclass is *defined*, not via
a post-boot scan (which would miss classes not yet autoloaded in development). This is wired up
by installing an `ApplicationRecord.inherited` hook from `config.to_prepare` (see
`config/initializers/default_module_registry.rb`), so it's already in place before Rails eager
loads every model in production.

Consumers today: `model_driven_api`'s `ModelDrivenApiDefaultJsonAttrs` (default `json_attrs`)
and `thecore_ui_rails_admin`'s `ThecoreUiRailsAdminDefaultNavigationConcern` (default
`navigation_label`/`navigation_icon`) — see their own READMEs for what each one does. A model
that still needs custom behavior keeps (or adds) an explicit `Api::ModelName`/
`RailsAdmin::ModelName` concern exactly as before; it simply runs *after* the default and
overrides it. Full mechanics (idempotency, abstract/STI exclusion, `to_prepare` vs
`after_initialize` timing) are documented in this gem's `docs/agents/default-module-registry.md`.

---

## Background jobs: no retries by default

Every app using this gem runs its background jobs on Sidekiq in production, and by default:

- **a failed job is never retried** (`retry: false`): it runs once, and Sidekiq keeps it in
  neither the retry set nor the Dead Set;
- **only the latest failed job is kept in Redis**: `sidekiq-failures` (from
  `thecore_background_jobs`) stores each failed job's full payload, arguments included, in the
  Redis `failed` set; it is capped at 1, still visible in the Sidekiq web UI's Failures tab;
- **every failure is written to the Rails log** by `ThecoreBackendCommons::DiscardedJobLogger`:
  job class (or `Mailer#action`), queue, jid and error, never the arguments.

Why zero: in a Thecore app in production, mail jobs carrying a whole PDF in their arguments
failed with a permanent SMTP error and were retried for weeks, then kept in the Dead Set. Redis
grew to 23 GB until the host's OOM killer put it in a restart loop and no job ran for three days
(`docs/adr/0002-no-job-retries-failures-logged.md`).

### Changing the defaults on an installation

Set these in the environment of both the `backend` and the `worker` containers. On an
installation deployed by `thecore_devcontainer` that is the target's
`vendor/deploytargets/<provider>/<customer>.env`, which reaches both containers through their
`env_file` (`thecore_devcontainer` ADR 0002); on a hand-written compose, its `environment:`.

| Variable | Unset or blank | Accepted values | Effect |
| --- | --- | --- | --- |
| `THECORE_JOB_RETRIES` | `0` (no retries) | a whole number >= 0 | how many times Sidekiq retries a failed job, app-wide |
| `THECORE_FAILED_JOBS_KEPT` | `1` | a whole number >= 1 | how many failed jobs stay in the Redis `failed` set |

Any other value (`yes`, `-1`, `1.5`, ...) stops the app at boot with an error naming the
variable: a typo never silently turns retries back on. With retries above 0, a job that uses
them all ends in Sidekiq's Dead Set, which is capped by count and age but not by size.

### Changing it for one job

A job class sets its own retry count with Sidekiq's option, which wins over the app-wide value
in both directions (it works on ActiveJob classes and mailers' jobs alike):

```ruby
class SyncInventoryJob < ApplicationJob
  sidekiq_options retry: 3   # or retry: false when THECORE_JOB_RETRIES is above 0
end
```

**Don't use ActiveJob's `retry_on` for this.** It retries independently of Sidekiq: on failure
ActiveJob enqueues a new copy of the job, arguments included, whatever `THECORE_JOB_RETRIES`
says, and the copies never show up as Sidekiq retries.

### Logging failures somewhere else too

Add your own Sidekiq death handler next to the default one; both run:

```ruby
# config/initializers/sidekiq.rb in the app
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, exception) { MyErrorLog.record(job["jid"], exception) }
end
```

---

## Invio email e configurazione SMTP

### Configurazione

Le impostazioni SMTP sono salvate in `ThecoreSettings` (namespace `:smtp`) e vengono caricate automaticamente dai seeds del gem:

| Chiave              | Descrizione                                                                 |
| ------------------- | --------------------------------------------------------------------------- |
| `address`           | Indirizzo del server SMTP (obbligatorio per abilitare la consegna)          |
| `port`              | Porta (default `587`); impostare `465` per SMTPS (SSL implicito)           |
| `domain`            | Dominio HELO                                                                |
| `user_name`         | Username per l'autenticazione                                               |
| `password`          | Password per l'autenticazione                                               |
| `authentication`    | `plain`, `login`, `cram_md5`, oppure `none`/vuoto per disabilitare l'auth  |
| `enable_starttls_auto` | Impostare a `false`, `f`, `0` o `no` per disabilitare STARTTLS. Ignorato se `port` è `465` (SMTPS usa TLS implicito). |
| `from`              | Indirizzo mittente                                                          |

**Nota porta 465 (SMTPS):** la connessione viene wrappata in SSL dal primo byte. Impostare `enable_starttls_auto` a `false` non è sufficiente: occorre usare la porta `465` affinché `SmtpConfig` abiliti automaticamente `tls: true`. Le due modalità (SMTPS e STARTTLS) sono mutuamente esclusive — mescolarle causa un `Net::ReadTimeout`.

### Usare SmtpDeliverable nei mailer

Includere il concern `SmtpDeliverable` in qualsiasi `ActionMailer::Base` per leggere le impostazioni SMTP da `ThecoreSettings` al momento dell'invio (nessun riavvio necessario quando le impostazioni cambiano):

```ruby
class MyMailer < ApplicationMailer
  include SmtpDeliverable

  def my_email
    mail(
      from: smtp_setting(:from),
      to: "recipient@example.com",
      subject: "Hello"
    )
  end
end
```

Il concern registra automaticamente un `after_action :configure_smtp_delivery` che sovrascrive il delivery method con le impostazioni lette da `ThecoreSettings`. Se `smtp.address` è vuoto, il mailer usa il delivery method configurato nell'ambiente Rails (es. `:test` o `:letter_opener` in sviluppo).

Il metodo helper `smtp_setting(key)` è disponibile in tutta la classe mailer.

### Usare SmtpConfig direttamente

`ThecoreBackendCommons::SmtpConfig` è un modulo Ruby puro utilizzabile anche al di fuori dei mailer (es. script, job, rake task):

```ruby
opts = ThecoreBackendCommons::SmtpConfig.delivery_options
# => { address: "smtp.example.com", port: 465, tls: true, ... }

ThecoreBackendCommons::SmtpConfig.setting(:from)
# => "noreply@example.com"
```

### Testare la configurazione SMTP

Il gem espone `ThecoreBackendCommons::SmtpTester` e un rake task, disponibili automaticamente in qualsiasi app che include questo gem.

**Da rake task (shell):**

```bash
rails thecore_backend_commons:smtp:test[destinatario@example.com]
```

**Da Rails console:**

```ruby
ThecoreBackendCommons::SmtpTester.call("destinatario@example.com")
```

Se non si passa un indirizzo, in entrambi i casi viene usato `ThecoreSettings mytask.default_email`.

Lo tester stampa i parametri SMTP effettivamente usati (inclusi `tls` e `enable_starttls_auto`) prima di tentare la consegna. Restituisce `true`/`false` dal console e exit code `1` dal rake task in caso di errore.
