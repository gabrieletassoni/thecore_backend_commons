class ActivityLogChannel < ApplicationCable::Channel
  def subscribed
    stream_from "messages"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def receive(data)
    ActionCable.server.broadcast("messages", {message: "ActionCable is connected and received: #{data["message"]}", topic: data["topic"].presence || "general"}) if data["namespace"] == "subscriptions"
  end
end
