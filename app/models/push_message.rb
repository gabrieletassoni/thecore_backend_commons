class PushMessage < ApplicationRecord
  belongs_to :push_subscriber
  belongs_to :sender, class_name: "User", foreign_key: :sender_user_id, optional: true
  validates :title, presence: true
  validates :body, presence: true
end
