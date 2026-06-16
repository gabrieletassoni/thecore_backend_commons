module ThecoreBackendCommons
  class PushNotificationService
    MAX_MESSAGES_DEFAULT = 500

    def self.dispatch(subscriber, message)
      new(subscriber, message).dispatch
    end

    def initialize(subscriber, message)
      @subscriber = subscriber
      @message = message
    end

    def dispatch
      send_push
      prune_old_messages
      @message
    rescue => e
      Rails.logger.error("[PushNotificationService] dispatch failed: #{e.message}")
      @message
    end

    private

    def send_push
      WebPush.payload_send(
        message: JSON.generate(payload),
        endpoint: @subscriber.endpoint,
        p256dh: @subscriber.p256dh,
        auth: @subscriber.auth,
        vapid: vapid_options
      )
      @message.update!(sent_at: Time.current)
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      @subscriber.expire!
    end

    def payload
      { title: @message.title, body: @message.body, url: @message.url, icon: @message.icon }.compact
    end

    def vapid_options
      {
        public_key: ThecoreSettings::Setting.where(ns: :vapid, key: :public_key).pluck(:raw).first,
        private_key: ThecoreSettings::Setting.where(ns: :vapid, key: :private_key).pluck(:raw).first,
        subject: "mailto:#{ThecoreSettings::Setting.where(ns: :vapid, key: :contact_email).pluck(:raw).first.presence || 'admin@example.com'}"
      }
    end

    def prune_old_messages
      limit = ThecoreSettings::Setting.where(ns: :vapid, key: :max_messages_per_subscriber).pluck(:raw).first&.to_i || MAX_MESSAGES_DEFAULT
      count = @subscriber.push_messages.count
      return unless count > limit
      oldest_ids = @subscriber.push_messages.order(created_at: :asc).limit(count - limit).pluck(:id)
      PushMessage.where(id: oldest_ids).delete_all
    end
  end
end
