class PushMessage < ApplicationRecord
  belongs_to :push_subscriber
  validates :title, presence: true
  validates :body, presence: true
end
