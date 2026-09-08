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

  # --- time-zone awareness (TimeZoneAware, issue #28) ---

  def set_server_time_zone(value)
    ThecoreSettings::Setting.where(ns: :main, key: :time_zone).destroy_all
    Settings.unload!
    Settings.ns(:main).time_zone = value if value
  end

  test "sent_at_record_tz, received_at_record_tz, and read_at_record_tz localize independently" do
    set_server_time_zone("Europe/Rome")
    now = Time.current
    msg = PushMessage.create!(
      push_subscriber: @subscriber, title: "Hi", body: "Hello",
      sent_at: now, received_at: now, read_at: now,
      sent_at_time_zone: "Europe/Rome",
      received_at_time_zone: "America/Santiago",
      read_at_time_zone: nil
    )

    assert_equal "Europe/Rome", msg.sent_at_record_tz.time_zone.name
    assert_equal "America/Santiago", msg.received_at_record_tz.time_zone.name
    assert_equal "Europe/Rome", msg.read_at_record_tz.time_zone.name # falls back to server zone
  end

  test "sent_at_server_tz localizes to the server zone regardless of the record's own zone" do
    set_server_time_zone("Europe/Rome")
    msg = PushMessage.create!(
      push_subscriber: @subscriber, title: "Hi", body: "Hello",
      sent_at: Time.current, sent_at_time_zone: "America/Santiago"
    )

    assert_equal "Europe/Rome", msg.sent_at_server_tz.time_zone.name
  end

  test "an invalid sent_at_time_zone is rejected on save" do
    msg = PushMessage.new(push_subscriber: @subscriber, title: "Hi", body: "Hello", sent_at_time_zone: "Not/AZone")

    assert_not msg.valid?
    assert_not_empty msg.errors[:sent_at_time_zone]
  end
end
