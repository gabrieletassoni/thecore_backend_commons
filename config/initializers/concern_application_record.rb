require 'active_support/concern'

module ApplicationRecordConcern
  extend ActiveSupport::Concern
  included do
    after_validation :validation_ko

    after_commit :message_ok

    after_rollback :message_ko

    def validation_ko
      ActionCable.server.broadcast("messages", build_message(false, false, self.errors.full_messages.uniq)) if self.errors.any? && !is_model_forbidden
    end

    def message_ok
      ActionCable.server.broadcast("messages", build_message(true, true, [])) unless is_model_forbidden
    end

    def message_ko
      ActionCable.server.broadcast("messages", build_message(false, true, [])) unless is_model_forbidden
    end

    def is_model_forbidden
      [ 'User', 'Role' ].include?(self.class.name)
    end

    def build_message success, valid, errors
      { topic: :record, action: detect_action, class: self.class.name, success: success, valid: valid, errors: errors, record: self}
    end

    def detect_action
      return :create if transaction_include_any_action?([:create])
      return :update if transaction_include_any_action?([:update])
      :destroy
    end
  end
end
