class PushDispatchJob < ApplicationJob
  queue_as :"#{ENV.fetch('COMPOSE_PROJECT_NAME', 'default')}_default"

  def perform(push_message_id)
    message = PushMessage.find_by(id: push_message_id)
    return unless message

    ThecoreBackendCommons::PushNotificationService.dispatch(message.push_subscriber, message)
  end
end
