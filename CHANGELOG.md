# Changelog

## [3.4.0] - 2026-06-30

### Added
- **`PushDispatchJob`** (`app/jobs/push_dispatch_job.rb`) — ActiveJob for async Web Push dispatch. Loads a `PushMessage` by id, calls `ThecoreBackendCommons::PushNotificationService.dispatch(subscriber, message)`. Queue: `"#{ENV.fetch('COMPOSE_PROJECT_NAME', 'default')}_default"`. Enqueued by `Endpoints::PushSubscriber#send_push` (bulk path) and `#broadcast_push` — one job per subscriber.

## Unreleased

### Changed
- **Replaced `webpush` (abandoned, last release 2020) with `web-push ~> 3.0`** (pushpad fork, actively maintained, native OpenSSL 3.0 support). All `Webpush` references updated to `WebPush`. No monkey-patch needed — web-push 3.x handles OpenSSL 3.0 natively. Required bumping `jwt` dependency to `>= 2.4` in `model_driven_api` (web-push 3.x requires jwt ~> 3.0; jwt 3.x is backward compatible with existing `JWT.encode`/`JWT.decode` usage).

### Added
- `PushNotificationChannel` ActionCable channel (`app/channels/push_notification_channel.rb`) — real-time push notification delivery; supports subscription by `subscriber_id` (single subscriber room) or `user_id` (all active subscriber rooms); class method `broadcast_to(subscriber, message)` for server-side broadcast
- `PushMessage` model (`belongs_to :push_subscriber`, validates `title` and `body` presence) with fields `title`, `body`, `url`, `icon`, `sent_at`, `received_at`, `read_at`
- Migration `create_push_messages` (`push_subscriber_id` FK, index on `push_subscriber_id`)
- `PushSubscriber` now `has_many :push_messages, dependent: :destroy`
- `ThecoreBackendCommons::PushNotificationService` — dispatches Web Push via `Webpush.payload_send`, sets `message.sent_at` on success, calls `subscriber.expire!` on expired/invalid subscription errors, prunes oldest messages per subscriber when count exceeds `vapid.max_messages_per_subscriber` limit (default 500)
- Dummy test schema includes `thecore_settings` table to support real ThecoreSettings records in tests
- `PushSubscriber` model with `active` scope, `subscribe_for` upsert class method, and `expire!` instance method for VAPID Web Push subscription management
- Migration `create_push_subscribers` (`endpoint` unique index, `user_id` FK, `p256dh`, `auth`, `user_agent`, `expired_at`)
- `webpush` gem dependency for VAPID protocol support
- VAPID ThecoreSettings seeds (`vapid.public_key`, `vapid.private_key`, `vapid.contact_email`, `vapid.max_messages_per_subscriber`)
- CLAUDE.md documenting architecture, test infrastructure, and ThecoreSettings keys
- Test infrastructure for the dummy app: `ModelDrivenApi` stub, `action_mailbox`/`assets` config stubs, `User`/`Ability` model stubs, `has_rich_text` stub
