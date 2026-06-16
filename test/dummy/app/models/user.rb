class User < ApplicationRecord
  has_many :push_subscribers, dependent: :destroy

  def authenticate(password)
    return nil if encrypted_password.blank?
    BCrypt::Password.new(encrypted_password).is_password?(password) ? self : nil
  end
end
