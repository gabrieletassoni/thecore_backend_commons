require "test_helper"
require "minitest/mock"
require "bcrypt"

class PushNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "service_test@example.com", encrypted_password: BCrypt::Password.create("password123"))
    @subscriber = PushSubscriber.subscribe_for(
      @user,
      endpoint: "https://example.com/push/service1",
      p256dh: "p256dh_key",
      auth: "auth_token"
    )
    @message = PushMessage.create!(
      push_subscriber: @subscriber,
      title: "Test Title",
      body: "Test Body",
      url: "https://example.com",
      icon: "/icon.png"
    )
  end

  def teardown
    ThecoreSettings::Setting.delete_all
    PushMessage.delete_all
    PushSubscriber.delete_all
    User.delete_all
  end

  # Tracer bullet: dispatch with stubbed WebPush populates sent_at
  test "dispatch sets sent_at on successful push" do
    WebPush.stub(:payload_send, nil) do
      result = ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
      assert_not_nil result.sent_at
    end
  end

  # dispatch returns the message object
  test "dispatch returns the message" do
    WebPush.stub(:payload_send, nil) do
      result = ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
      assert_equal @message, result
    end
  end

  # dispatch with ExpiredSubscription sets subscriber.expired_at
  test "dispatch with ExpiredSubscription expires the subscriber" do
    expired_error = WebPush::ExpiredSubscription.new(double_response(410), "endpoint")
    WebPush.stub(:payload_send, ->(*_args, **_kwargs) { raise expired_error }) do
      ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
      assert_not_nil @subscriber.reload.expired_at
    end
  end

  # dispatch with InvalidSubscription expires the subscriber
  test "dispatch with InvalidSubscription expires the subscriber" do
    invalid_error = WebPush::InvalidSubscription.new(double_response(404), "endpoint")
    WebPush.stub(:payload_send, ->(*_args, **_kwargs) { raise invalid_error }) do
      ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
      assert_not_nil @subscriber.reload.expired_at
    end
  end

  # Pruning: when subscriber has more messages than limit, oldest are removed
  test "pruning removes oldest messages when over limit" do
    # Set limit to 3 via ThecoreSettings
    ThecoreSettings::Setting.create!(ns: "vapid", key: "max_messages_per_subscriber", raw: "3")

    # Create 4 more messages (1 from setup + 4 = 5 total)
    4.times do |i|
      PushMessage.create!(push_subscriber: @subscriber, title: "Msg #{i}", body: "Body #{i}")
    end
    assert_equal 5, @subscriber.push_messages.count

    WebPush.stub(:payload_send, nil) do
      ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
    end

    assert_equal 3, @subscriber.push_messages.count
  end

  # Pruning does not delete messages when under limit
  test "pruning keeps messages when under limit" do
    ThecoreSettings::Setting.create!(ns: "vapid", key: "max_messages_per_subscriber", raw: "10")

    WebPush.stub(:payload_send, nil) do
      ThecoreBackendCommons::PushNotificationService.dispatch(@subscriber, @message)
    end

    # 1 message from setup, none deleted
    assert_equal 1, @subscriber.push_messages.count
  end

  private

  # Builds a minimal response double for WebPush error constructors
  def double_response(status_code)
    response = Object.new
    response.define_singleton_method(:code) { status_code.to_s }
    response.define_singleton_method(:message) { "Error #{status_code}" }
    response.define_singleton_method(:body) { "" }
    response
  end
end
