require "test_helper"
require "jwt"
require "bcrypt"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup do
    @user = User.create!(email: "cable-#{SecureRandom.hex(4)}@example.com",
                         encrypted_password: BCrypt::Password.create("password123"))
    @secret = Rails.application.credentials.dig(:secret_key_base).presence || ENV["SECRET_KEY_BASE"]
  end

  def jwt_for(user_id, secret: @secret)
    ::JWT.encode({ user_id: user_id }, secret, "HS256")
  end

  test "connects with a JWT signed with the server secret" do
    connect params: { token: jwt_for(@user.id) }
    assert_equal @user.id, connection.current_user.id
  end

  test "rejects a JWT forged with the wrong secret" do
    # The attack the signature check closes: a token carrying a real user_id but signed with a
    # key the caller made up. Before verification was enabled this authenticated as that user.
    forged = jwt_for(@user.id, secret: "not-the-server-secret")
    assert_reject_connection { connect params: { token: forged } }
  end

  test "rejects an unsigned (alg=none) token" do
    unsigned = ::JWT.encode({ user_id: @user.id }, nil, "none")
    assert_reject_connection { connect params: { token: unsigned } }
  end

  test "rejects a connection with no token" do
    assert_reject_connection { connect }
  end

  test "rejects a validly-signed token for a non-existent user" do
    assert_reject_connection { connect params: { token: jwt_for(-1) } }
  end

  # A locked user (users.locked) must not open the WebSocket either, whatever credential they
  # still hold (Odoo #6051): ActivityLogChannel streams every record change.
  test "rejects a valid JWT of a locked user" do
    @user.update!(locked: true)
    assert_reject_connection { connect params: { token: jwt_for(@user.id) } }
  end

  test "connects with the Warden session of an unlocked user" do
    connect env: { "warden" => warden_returning(@user) }
    assert_equal @user.id, connection.current_user.id
  end

  test "rejects the Warden session of a locked user" do
    @user.update!(locked: true)
    assert_reject_connection { connect env: { "warden" => warden_returning(@user) } }
  end

  # What Devise does for a locked user on a real host: its after_set_user hook throws :warden
  # when the session's user is fetched.
  test "rejects a Warden session whose user Devise refuses" do
    refusing = Object.new
    def refusing.user = throw(:warden, scope: :user, message: :locked)
    assert_reject_connection { connect env: { "warden" => refusing } }
  end

  test "connects with the m2m token of an unlocked user, and rejects it once locked" do
    with_m2m_token_column do
      token = "m2m-#{SecureRandom.hex(8)}"
      @user.update!(encrypted_access_token: BCrypt::Password.create(token))

      connect params: { token: token }
      assert_equal @user.id, connection.current_user.id

      @user.update!(locked: true)
      assert_reject_connection { connect params: { token: token } }
    end
  end

  private

  def warden_returning(user)
    Struct.new(:user).new(user)
  end

  # The m2m column comes from thecore-spot-overrides, above this gem, so the dummy schema leaves it
  # out; added inside the test's transaction, it is rolled back with it.
  def with_m2m_token_column
    ActiveRecord::Base.connection.add_column :users, :encrypted_access_token, :string
    User.reset_column_information
    @user = User.find(@user.id)
    yield
  ensure
    User.reset_column_information
  end
end
