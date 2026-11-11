# Web Push

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (PushSubscriber/PushMessage models, PushNotificationChannel, PushDispatchJob, PushNotificationService, VAPID settings, migrations). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Models

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

Fields: `push_subscriber_id` (FK), `title` (string, required), `body` (text, required), `url` (string, optional), `icon` (string, optional), `sent_at` (datetime), `received_at` (datetime), `read_at` (datetime), `sender_user_id` (FK to `users`, optional — null for system-generated notifications), `message_type` (string, default `"communication"` — `"communication"` for general notifications, `"message"` for direct user messages). Declares `sent_at`/`received_at`/`read_at` through `TimeZoneAware` (see `docs/agents/time-zone-aware.md`), gaining `sent_at_time_zone`/`received_at_time_zone`/`read_at_time_zone` columns.

Associations: `belongs_to :sender, class_name: "User", foreign_key: :sender_user_id, optional: true`. Note: `sender_user_id` identifies the *human sender*; `user_id` in `push_subscribers` identifies the *recipient* — do not confuse the two.

Validations: `title` and `body` presence required.

API serialization (`json_attrs`) and RailsAdmin configuration are applied from external gems following the Thecore ATOM isolation principle (see `docs/agents/atom-isolation.md`).

## PushNotificationChannel

**`PushNotificationChannel`** (`app/channels/push_notification_channel.rb`):
ActionCable channel for delivering push notifications in real-time to connected browser clients.

Two subscription modes:
- `params[:subscriber_id]` — streams from a single subscriber's room (only if it belongs to `current_user`)
- `params[:user_id]` — streams from all active subscribers of that user (only if `params[:user_id].to_i == current_user.id`)

Stream room name: `"push_notifications_subscriber_#{subscriber.id}"`

Class method: `PushNotificationChannel.broadcast_to(subscriber, message)` — broadcasts `message.as_json` to the subscriber's room via `ActionCable.server.broadcast`.

## Jobs

**`PushDispatchJob`** (`app/jobs/push_dispatch_job.rb`):
ActiveJob job that dispatches a single `PushMessage` via `PushNotificationService`. Enqueued by `Endpoints::PushSubscriber#send_push` (bulk path) — one job per subscriber.

- Queue: `"#{ENV.fetch('COMPOSE_PROJECT_NAME', 'default')}_default"` — follows the Thecore/Spot COMPOSE_PROJECT_NAME convention.
- `perform(push_message_id)` — loads the `PushMessage` by id (returns early if not found), then calls `ThecoreBackendCommons::PushNotificationService.dispatch(subscriber, message)`.

## PushNotificationService

**`ThecoreBackendCommons::PushNotificationService`** — sends a Web Push notification to a subscriber and records the result on the `PushMessage`.

Key interface:
- `PushNotificationService.dispatch(subscriber, message)` — class-level entry point; sends the push, updates `message.sent_at` on success, calls `subscriber.expire!` on `Webpush::ExpiredSubscription` or `Webpush::InvalidSubscription`, prunes oldest messages if count exceeds `vapid.max_messages_per_subscriber` limit, and always returns `message`. Errors are rescued and logged; they do not propagate.
- VAPID keys are read from `ThecoreSettings` (ns `:vapid`, keys `public_key`, `private_key`, `contact_email`) at dispatch time.
- Push payload includes: `id` (PushMessage PK), `title`, `body`, `sent_at` (ISO 8601, from `created_at`), `type` (from `message_type`, default `"communication"`), `url`, `icon` (nil fields removed via `compact`).

## VAPID (ns: `:vapid`)
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
- `20260629000001_add_message_type_to_push_messages` — adds `message_type` string column (not null, default `"communication"`) to `push_messages`
- `20260908000010_add_time_zone_columns_to_push_messages` — adds `sent_at_time_zone`/`received_at_time_zone`/`read_at_time_zone` string columns to `push_messages` (version deliberately picked past `mytask`'s own `2026090800000{1..9}` range — engine migration versions share one `schema_migrations` table across the whole host app, so they must be globally unique, not just unique within this gem)
