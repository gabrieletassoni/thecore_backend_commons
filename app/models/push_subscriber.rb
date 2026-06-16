class PushSubscriber < ApplicationRecord
  belongs_to :user
  has_many :push_messages, dependent: :destroy
  validates :endpoint, presence: true, uniqueness: true
  scope :active, -> { where(expired_at: nil) }

  def expire!
    update!(expired_at: Time.current)
  end

  def self.subscribe_for(user, endpoint:, p256dh: nil, auth: nil, user_agent: nil)
    record = find_or_initialize_by(endpoint: endpoint)
    record.user = user
    record.p256dh = p256dh
    record.auth = auth
    record.user_agent = user_agent
    record.expired_at = nil
    record.save!
    record
  end
end
