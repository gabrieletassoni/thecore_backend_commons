class ActivityLogChannel < ApplicationCable::Channel
  def subscribed
    stream_from "messages"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # https://cableready.stimulusreflex.com/troubleshooting/#verify-actioncable

  def receive(data)
    puts data["message"]
    ActionCable.server.broadcast("messages", "ActionCable is connected")
  end
end
