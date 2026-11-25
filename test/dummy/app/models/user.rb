class User < ApplicationRecord
  has_many :push_subscribers, dependent: :destroy

  def authenticate(password)
    return nil if encrypted_password.blank?
    BCrypt::Password.new(encrypted_password).is_password?(password) ? self : nil
  end

  # Mirrors thecore_auth_commons User#active_for_authentication? (>= 3.7.0): a locked user may
  # not authenticate.
  def active_for_authentication?
    !locked?
  end
end
