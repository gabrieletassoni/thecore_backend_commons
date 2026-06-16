require "test_helper"
require "bcrypt"

class PushNotificationChannelTest < ActionCable::Channel::TestCase
  tests PushNotificationChannel
  def setup
    @user = User.create!(email: "push_test@example.com", encrypted_password: BCrypt::Password.create("password123"))
    @other_user = User.create!(email: "other@example.com", encrypted_password: BCrypt::Password.create("password456"))
    @subscriber = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1", p256dh: "key1", auth: "auth1")
    @other_subscriber = PushSubscriber.subscribe_for(@other_user, endpoint: "https://example.com/push/2", p256dh: "key2", auth: "auth2")
  end

  def teardown
    PushSubscriber.delete_all
    User.delete_all
  end

  # Tracer bullet: subscribe with valid subscriber_id streams from the correct room
  test "subscribes to specific subscriber stream when subscriber_id belongs to current user" do
    stub_connection current_user: @user
    subscribe subscriber_id: @subscriber.id
    assert_has_stream "push_notifications_subscriber_#{@subscriber.id}"
  end

  # Subscribe with subscriber_id belonging to another user → no streams
  test "does not stream when subscriber_id belongs to another user" do
    stub_connection current_user: @user
    subscribe subscriber_id: @other_subscriber.id
    assert_no_streams
  end

  # Subscribe with user_id matching current user → streams for each active subscriber
  test "streams for all active subscribers when user_id matches current user" do
    second_subscriber = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/3", p256dh: "key3", auth: "auth3")
    stub_connection current_user: @user
    subscribe user_id: @user.id
    assert_has_stream "push_notifications_subscriber_#{@subscriber.id}"
    assert_has_stream "push_notifications_subscriber_#{second_subscriber.id}"
  end

  # Subscribe with user_id of another user → no streams
  test "does not stream when user_id belongs to another user" do
    stub_connection current_user: @user
    subscribe user_id: @other_user.id
    assert_no_streams
  end

  # broadcast_to sends the correct payload
  test "broadcast_to sends message payload to the correct stream" do
    message = PushMessage.create!(push_subscriber: @subscriber, title: "Hello", body: "World")
    PushNotificationChannel.broadcast_to(@subscriber, message)
    assert_broadcast_on("push_notifications_subscriber_#{@subscriber.id}", message.as_json)
  end
end
