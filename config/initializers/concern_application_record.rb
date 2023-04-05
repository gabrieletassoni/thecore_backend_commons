require 'active_support/concern'

module ApplicationRecordConcern
  extend ActiveSupport::Concern
  included do
    after_validation :validation_ko

    after_commit :message_ok

    after_rollback :message_ko

    def validation_ko
      ActionCable.server.broadcast("messages", { topic: :record, action: detect_action, success: false, valid: false, errors: self.errors.full_messages.uniq, record: self}) if self.errors.any?
    end

    def message_ok
      ActionCable.server.broadcast("messages", { topic: :record, action: detect_action, success: true, valid: true, errors: [], record: self})
    end

    def message_ko
      ActionCable.server.broadcast("messages", { topic: :record, action: detect_action, success: false, valid: true, errors: [], record: self})
    end

    def detect_action
      return :create if transaction_include_any_action?([:create])
      return :update if transaction_include_any_action?([:update])
      :destroy
    end
  end
end
