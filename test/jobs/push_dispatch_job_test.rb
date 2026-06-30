require "test_helper"
require "bcrypt"
require "minitest/mock"

class PushDispatchJobTest < ActiveJob::TestCase
  def setup
    @user = User.create!(email: "dispatch_job@example.com", encrypted_password: BCrypt::Password.create("password"))
    @subscriber = PushSubscriber.subscribe_for(@user, endpoint: "https://push.example.com/job-test", p256dh: "key", auth: "auth")
    @message = @subscriber.push_messages.create!(title: "Job Test", body: "Body")
  end

  def teardown
    PushMessage.delete_all
    PushSubscriber.delete_all
    User.delete_all
  end

  test "calls PushNotificationService.dispatch with the subscriber and message" do
    dispatched = []
    ThecoreBackendCommons::PushNotificationService.stub(:dispatch, ->(sub, msg) { dispatched << [sub.id, msg.id] }) do
      PushDispatchJob.new.perform(@message.id)
    end
    assert_equal [[@subscriber.id, @message.id]], dispatched
  end

  test "does nothing when message is not found" do
    assert_nothing_raised do
      PushDispatchJob.new.perform(0)
    end
  end

  test "queue name uses COMPOSE_PROJECT_NAME env var" do
    assert_equal :"#{ENV.fetch('COMPOSE_PROJECT_NAME', 'default')}_default", PushDispatchJob.queue_name.to_sym
  end
end
