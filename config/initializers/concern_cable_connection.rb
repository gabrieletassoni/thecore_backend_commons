require 'active_support/concern'

module CableConnectionConcern
  extend ActiveSupport::Concern
  included do
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected

    def find_verified_user
      # An already-authenticated Devise/Warden session (e.g. RailsAdmin in the browser) is
      # trusted, before looking at any token. Devise throws :warden when it refuses the session's
      # user (a locked one): outside the Warden middleware nobody catches it, so catch it here.
      warden_user = catch(:warden) { env["warden"]&.user }
      return verified(warden_user) if warden_user.is_a?(User)

      # Looks for a token in the query parameters, or in the "Authorization" header.
      m = request.query_parameters["token"].presence ||
          request.headers["Authorization"].to_s.split(" ").second&.strip
      return reject_unauthorized_connection if m.blank?

      # Machine-to-machine token (bcrypt-compared against each user's stored token). Guarded by a
      # column check so this generic gem also works in a host without m2m tokens (and so its own
      # dummy app, whose users table has no such column, doesn't abort the transaction).
      if User.column_names.include?("encrypted_access_token")
        m2m_user = User.where.not(encrypted_access_token: nil)
                       .find { |u| BCrypt::Password.new(u.encrypted_access_token) == m } rescue nil
        return verified(m2m_user) if m2m_user
      end

      # JWT: the signature MUST be verified, exactly like every REST request. Decoding with the
      # verification disabled (the previous behaviour) let a forged token carrying an arbitrary
      # user_id authenticate as any user over the WebSocket — and ActivityLogChannel streams every
      # record change, so that was a full read bypass. See docs/adr and the issue tracker.
      body = decode_verified_jwt(m)
      jwt_user = User.find_by(id: body[:user_id]) if body && body[:user_id]
      return verified(jwt_user) if jwt_user

      # Neither a valid m2m nor a valid JWT token: refuse the connection.
      reject_unauthorized_connection
    end

    # A locked user is refused whatever credential they still hold (session, m2m token, JWT):
    # User#active_for_authentication? is the check every login channel uses (thecore_auth_commons
    # >= 3.7.0; Odoo #6051).
    def verified(user)
      user.active_for_authentication? ? user : reject_unauthorized_connection
    end

    # Decodes and VERIFIES a JWT. Reuses model_driven_api's JsonWebToken when present, so the
    # WebSocket shares the REST API's signing key, key-rotation and single-session handling;
    # falls back to a signature-verifying decode so this gem still works on its own. Returns nil
    # on any invalid, forged or expired token.
    def decode_verified_jwt(token)
      if defined?(::JsonWebToken)
        ::JsonWebToken.decode(token)
      else
        secret = ::Rails.application.credentials.dig(:secret_key_base).presence || ENV["SECRET_KEY_BASE"]
        ::HashWithIndifferentAccess.new(::JWT.decode(token, secret, true, algorithm: "HS256")[0])
      end
    rescue StandardError
      nil
    end
  end
end
