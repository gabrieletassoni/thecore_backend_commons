require 'active_support/concern'

module ApplicationRecordConcern
  extend ActiveSupport::Concern
  included do
    after_commit :message_ok

    after_rollback :message_ko

    def message_ok
      ActionCable.server.broadcast("messages", { topic: :record, action: detect_action, success: true, record: self})
    end

    def message_ko
      ActionCable.server.broadcast("messages", { topic: :record, action: detect_action, success: false, record: self})
    end

    def detect_action
      return :create if transaction_include_any_action?([:create])
      return :update if transaction_include_any_action?([:update])
      :destroy
    end
  end
end
