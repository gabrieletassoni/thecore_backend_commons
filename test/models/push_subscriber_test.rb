require "test_helper"
require "bcrypt"

class PushSubscriberTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", encrypted_password: BCrypt::Password.create("password123"))
  end

  def teardown
    PushSubscriber.delete_all
    User.delete_all
  end

  test "subscribe_for creates a record" do
    sub = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1", p256dh: "key", auth: "auth")
    assert_not_nil sub.id
    assert_equal "https://example.com/push/1", sub.endpoint
  end

  test "active scope returns only non-expired" do
    PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1")
    expired = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/2")
    expired.expire!
    assert_equal 1, PushSubscriber.active.count
  end

  test "subscribe_for with existing endpoint updates record" do
    PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1", p256dh: "old_key")
    PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1", p256dh: "new_key")
    assert_equal 1, PushSubscriber.where(endpoint: "https://example.com/push/1").count
    assert_equal "new_key", PushSubscriber.find_by(endpoint: "https://example.com/push/1").p256dh
  end

  test "subscribe_for clears expired_at" do
    sub = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1")
    sub.expire!
    assert_not_nil sub.reload.expired_at
    PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1")
    assert_nil sub.reload.expired_at
  end

  test "endpoint must be present" do
    sub = PushSubscriber.new(user: @user, endpoint: "")
    assert_not sub.valid?
    assert_includes sub.errors[:endpoint], "can't be blank"
  end

  test "expire! sets expired_at" do
    sub = PushSubscriber.subscribe_for(@user, endpoint: "https://example.com/push/1")
    assert_nil sub.expired_at
    sub.expire!
    assert_not_nil sub.reload.expired_at
  end

end
