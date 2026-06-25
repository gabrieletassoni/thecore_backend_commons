# CLAUDE.md — thecore_backend_commons

Rails engine gem providing shared backend utilities for the Thecore ecosystem: ActionCable channels, SMTP helpers, application record concerns, and Web Push notification infrastructure.

## Commands

```bash
# Run tests (from inside the submodule directory)
env -u DATABASE_URL BUNDLE_GEMFILE=Gemfile RAILS_ENV=test bundle exec ruby -Itest -Ilib test/models/push_subscriber_test.rb

# Run all tests
env -u DATABASE_URL BUNDLE_GEMFILE=Gemfile RAILS_ENV=test bundle exec ruby -Itest -Ilib -e "Dir['test/**/*_test.rb'].each { |f| require_relative f }"

# Bundle install
BUNDLE_GEMFILE=Gemfile bundle install
```

**Important**: always unset `DATABASE_URL` when running tests — the devcontainer environment sets it to a PostgreSQL URL that overrides the test SQLite3 config.

## Architecture

### Entry point

`lib/thecore_backend_commons.rb` — requires all dependencies including `webpush` (for VAPID push notifications).

### Models

**`PushSubscriber`** (`app/models/push_subscriber.rb`):
Represents a browser/device subscription registered by a `User` for receiving Web Push notifications via VAPID.

Fields: `user_id` (FK), `endpoint` (unique, text), `p256dh`, `auth`, `user_agent`, `expired_at` (datetime, null = active).

Key interface:
- `PushSubscriber.active` — scope, returns only records with `expired_at IS NULL`
- `PushSubscriber.subscribe_for(user, endpoint:, p256dh:, auth:, user_agent:)` — upsert by endpoint; resets `expired_at` if subscriber was expired
- `subscriber.expire!` — sets `expired_at = Time.current`
- `subscriber.push_messages` — `has_many :push_messages, dependent: :destroy`

API serialization (`json_attrs`) and RailsAdmin configuration are applied from external gems: `model_driven_api` registers `json_attrs` with user data; `thecore_ui_rails_admin` registers rails_admin config. The model itself has no direct dependency on these gems.

**`PushMessage`** (`app/models/push_message.rb`):
Records a push notification payload tied to a `PushSubscriber`. Created before dispatch; `sent_at` is populated after successful delivery.

Fields: `push_subscriber_id` (FK), `title` (string, required), `body` (text, required), `url` (string, optional), `icon` (string, optional), `sent_at` (datetime), `received_at` (datetime), `read_at` (datetime), `sender_user_id` (FK to `users`, optional — null for system-generated notifications).

Associations: `belongs_to :sender, class_name: "User", foreign_key: :sender_user_id, optional: true`. Note: `sender_user_id` identifies the *human sender*; `user_id` in `push_subscribers` identifies the *recipient* — do not confuse the two.

Validations: `title` and `body` presence required.

API serialization (`json_attrs`) and RailsAdmin configuration are applied from external gems following the Thecore ATOM isolation principle (see below).

### Channels

**`ActivityLogChannel`** (`app/channels/activity_log_channel.rb`):
Streams from the `"messages"` room. Used by the frontend to receive real-time model change notifications.

**`PushNotificationChannel`** (`app/channels/push_notification_channel.rb`):
ActionCable channel for delivering push notifications in real-time to connected browser clients.

Two subscription modes:
- `params[:subscriber_id]` — streams from a single subscriber's room (only if it belongs to `current_user`)
- `params[:user_id]` — streams from all active subscribers of that user (only if `params[:user_id].to_i == current_user.id`)

Stream room name: `"push_notifications_subscriber_#{subscriber.id}"`

Class method: `PushNotificationChannel.broadcast_to(subscriber, message)` — broadcasts `message.as_json` to the subscriber's room via `ActionCable.server.broadcast`.

### Mailer concerns

**`SmtpDeliverable`** (`app/mailers/concerns/smtp_deliverable.rb`):
Include in ActionMailer subclasses to configure SMTP from `ThecoreSettings` at send time (no restart needed).

### Lib

**`ThecoreBackendCommons::SmtpConfig`** — reads SMTP settings from `ThecoreSettings` (ns: `:smtp`).
**`ThecoreBackendCommons::SmtpTester`** — sends a test email; callable via `SmtpTester.call("me@example.com")`.
**`ThecoreBackendCommons::PushNotificationService`** — sends a Web Push notification to a subscriber and records the result on the `PushMessage`.

Key interface:
- `PushNotificationService.dispatch(subscriber, message)` — class-level entry point; sends the push, updates `message.sent_at` on success, calls `subscriber.expire!` on `Webpush::ExpiredSubscription` or `Webpush::InvalidSubscription`, prunes oldest messages if count exceeds `vapid.max_messages_per_subscriber` limit, and always returns `message`. Errors are rescued and logged; they do not propagate.
- VAPID keys are read from `ThecoreSettings` (ns `:vapid`, keys `public_key`, `private_key`, `contact_email`) at dispatch time.

## ThecoreSettings keys

### SMTP (ns: `:smtp`)
`address`, `port`, `domain`, `user_name`, `password`, `authentication`, `enable_starttls_auto`, `from`, `delivery_method`

### VAPID (ns: `:vapid`)
| Key | Purpose | Default |
|-----|---------|---------|
| `public_key` | VAPID public key (base64url) | generated at seed |
| `private_key` | VAPID private key (base64url) | generated at seed |
| `contact_email` | Contact email for VAPID `sub` claim | `""` |
| `max_messages_per_subscriber` | PushMessage retention limit per subscriber | `"500"` |

Keys are generated automatically at `db:seed` if absent. **Regenerating keys invalidates all existing PushSubscribers** — browsers must re-subscribe.

## Migrations

- `20260616000001_create_push_subscribers` — creates `push_subscribers` table with unique index on `endpoint`
- `20260616000002_create_push_messages` — creates `push_messages` table with FK to `push_subscribers`
- `20260625000001_add_sender_user_id_to_push_messages` — adds optional `sender_user_id` (FK to `users`) to `push_messages`

## ATOM isolation principle

`thecore_backend_commons` owns only core domain logic (models, channels, services). It has **no dependency** on `model_driven_api` or `rails_admin`. API serialization (`json_attrs`) and RailsAdmin configuration for `PushSubscriber` and `PushMessage` are injected by downstream gems via `after_initialize`:

| Gem | What it injects | Where |
|-----|----------------|-------|
| `model_driven_api` | `ModelDrivenApiPushSubscriber` / `ModelDrivenApiPushMessage` (json_attrs) | `config/initializers/after_initialize_for_model_driven_api.rb` |
| `thecore_ui_rails_admin` | `ThecoreUiRailsAdminPushSubscriberConcern` / `ThecoreUiRailsAdminPushMessageConcern` (rails_admin) | `config/initializers/after_initialize.rb` |

`name` and `surname` are included in `only:` for the user/sender serialization — Rails `as_json` silently omits columns that don't exist on the model, so the serialization is safe across all environments.

## Test infrastructure

The dummy app (`test/dummy/`) uses SQLite3. Key stubs in `test/dummy/config/application.rb`:
- `ModelDrivenApi.smart_merge` stub (model_driven_api not in bundle)
- `config.action_mailbox` stub (not in rails/all)
- `config.assets` stub (sprockets not in bundle)
- `User`, `Ability`, `ApplicationCable::Connection` preloaded before `run_load_hooks`
- `has_rich_text` stubbed via `ActiveSupport.on_load(:active_record)`
