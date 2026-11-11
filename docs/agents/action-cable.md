# ActionCable

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (ActivityLogChannel, WebSocket connection authentication). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Channels

**`ActivityLogChannel`** (`app/channels/activity_log_channel.rb`):
Streams from the `"messages"` room. Used by the frontend to receive real-time model change notifications.

## Connection authentication (`config/initializers/concern_cable_connection.rb`)

`CableConnectionConcern` is `include`d into the host's `ApplicationCable::Connection` (by
`config/initializers/after_initialize.rb`) and identifies `current_user` for every WebSocket
connection. `find_verified_user` tries, in order: an existing Warden/Devise session (cookie-based,
e.g. RailsAdmin), a machine-to-machine token (bcrypt-compared against each user's
`encrypted_access_token`), then a JWT.

**The JWT signature is verified** (since 3.9.1). `decode_verified_jwt` reuses `model_driven_api`'s
`JsonWebToken.decode` when that constant is defined — so the WebSocket shares the REST API's signing
key, key-rotation (`SECRET_KEY_BASE_PREVIOUS`) and single-session (`UsedToken`) handling — and falls
back to a signature-verifying `JWT.decode(token, secret, true, algorithm: "HS256")` when it isn't
(this gem's dummy app has no `model_driven_api`, so the fallback is what the tests exercise). Before
3.9.1 it decoded with verification disabled (`JWT.decode(m, key, false)`), so a token carrying any
`user_id` but signed with an attacker-chosen key authenticated as that user — and since
`ActivityLogChannel` streams every model change over the shared `"messages"` room, that was a full
cross-user read bypass. `test/channels/application_cable/connection_test.rb` covers a valid token,
a forged-signature token, an `alg=none` token, a missing token, and a validly-signed token for an
unknown user. The dummy `users` table carries `encrypted_access_token` so the m2m branch runs
realistically rather than aborting the test transaction on a missing column.
