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
      # trusted as-is, before looking at any token.
      warden_user = env["warden"]&.user
      return warden_user if warden_user

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
        return m2m_user if m2m_user
      end

      # JWT: the signature MUST be verified, exactly like every REST request. Decoding with the
      # verification disabled (the previous behaviour) let a forged token carrying an arbitrary
      # user_id authenticate as any user over the WebSocket — and ActivityLogChannel streams every
      # record change, so that was a full read bypass. See docs/adr and the issue tracker.
      body = decode_verified_jwt(m)
      jwt_user = User.find_by(id: body[:user_id]) if body && body[:user_id]
      return jwt_user if jwt_user

      # Neither a valid m2m nor a valid JWT token: refuse the connection.
      reject_unauthorized_connection
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
