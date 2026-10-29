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
end
