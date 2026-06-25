require "test_helper"
require "bcrypt"

class PushMessageTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "msg_test@example.com", encrypted_password: BCrypt::Password.create("password123"))
    @subscriber = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/msg1", p256dh: "key", auth: "auth")
  end

  def teardown
    PushMessage.delete_all
    PushSubscriber.delete_all
    User.delete_all
  end

  test "requires title" do
    msg = PushMessage.new(push_subscriber: @subscriber, body: "Hello")
    assert_not msg.valid?
    assert_includes msg.errors[:title], "can't be blank"
  end

  test "requires body" do
    msg = PushMessage.new(push_subscriber: @subscriber, title: "Hi")
    assert_not msg.valid?
    assert_includes msg.errors[:body], "can't be blank"
  end

  test "requires push_subscriber" do
    msg = PushMessage.new(title: "Hi", body: "Hello")
    assert_not msg.valid?
  end

  test "valid with title, body, and subscriber" do
    msg = PushMessage.new(push_subscriber: @subscriber, title: "Hi", body: "Hello")
    assert msg.valid?
  end

  test "belongs to push_subscriber" do
    msg = PushMessage.create!(push_subscriber: @subscriber, title: "Hi", body: "Hello")
    assert_equal @subscriber, msg.push_subscriber
  end

  test "push_subscriber has many push_messages" do
    PushMessage.create!(push_subscriber: @subscriber, title: "A", body: "First")
    PushMessage.create!(push_subscriber: @subscriber, title: "B", body: "Second")
    assert_equal 2, @subscriber.push_messages.count
  end

  test "destroying subscriber destroys push_messages" do
    PushMessage.create!(push_subscriber: @subscriber, title: "A", body: "First")
    assert_difference "PushMessage.count", -1 do
      @subscriber.destroy
    end
  end

  test "sender is optional" do
    msg = PushMessage.new(push_subscriber: @subscriber, title: "Hi", body: "Hello")
    assert msg.valid?
    assert_nil msg.sender
  end

  test "sender can be set to a user" do
    sender = User.create!(email: "sender@example.com", encrypted_password: BCrypt::Password.create("password123"))
    msg = PushMessage.create!(push_subscriber: @subscriber, title: "Hi", body: "Hello", sender: sender)
    assert_equal sender, msg.reload.sender
  end

end
