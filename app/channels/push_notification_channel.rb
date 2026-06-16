class PushNotificationChannel < ApplicationCable::Channel
  def subscribed
    if params[:subscriber_id].present?
      subscriber = PushSubscriber.active.find_by(id: params[:subscriber_id], user_id: current_user.id)
      stream_from "push_notifications_subscriber_#{subscriber.id}" if subscriber
    elsif params[:user_id].present? && params[:user_id].to_i == current_user.id
      PushSubscriber.active.where(user_id: current_user.id).each do |sub|
        stream_from "push_notifications_subscriber_#{sub.id}"
      end
    end
  end

  def unsubscribed; end

  def self.broadcast_to(subscriber, message)
    ActionCable.server.broadcast("push_notifications_subscriber_#{subscriber.id}", message.as_json)
  end
end
