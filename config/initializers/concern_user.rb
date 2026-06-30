# config.to_prepare do
#   User.class_eval do
#     has_many :push_subscribers, dependent: :destroy
#   end
# end

module ThecoreBackendCommonsUserConcern
  extend ActiveSupport::Concern

  included do
    has_many :push_subscribers, dependent: :destroy
    has_many :sent_push_messages, class_name: "PushMessage", foreign_key: :sender_user_id, dependent: :destroy
  end
end