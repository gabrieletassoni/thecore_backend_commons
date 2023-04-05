require 'active_support/concern'

module CableConnectionConcern
  extend ActiveSupport::Concern
  included do
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected

    def find_verified_user # this checks whether a user is authenticated with devise
      m = request.query_parameters["token"]

      body = ::HashWithIndifferentAccess.new(::JWT.decode(m, ::Rails.application.credentials.dig(:secret_key_base).presence||ENV["SECRET_KEY_BASE"], false)[0]) rescue nil
      if verified_user = (env['warden'].user.presence || User.find_by(id: body[:user_id]))
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
