require "active_support/concern"

module ApplicationRecordConcern
  extend ActiveSupport::Concern
  included do
    # Add to all the models the ability to manage attached assets with remove and append functionality
    has_many_attached :assets

    attr_accessor :remove_assets, :append_assets

    after_save :manage_assets

    # Broadcast messages via ActionCable for create, update, destroy actions
    after_validation :validation_ko

    after_commit :message_ok

    after_rollback :message_ko
  end

  # Private methods
  private

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
    ["User", "Role"].include?(self.class.name)
  end

  def build_message(success, valid, errors)
    { topic: :record, action: detect_action, class: self.class.name, success: success, valid: valid, errors: errors, record: self }
  end

  def detect_action
    return :create if transaction_include_any_action?([:create])
    return :update if transaction_include_any_action?([:update])
    :destroy
  end

  def manage_assets
    # 1. Gestione CANCELLAZIONE
    if remove_assets.present?
      ids_to_remove = remove_assets
      self.remove_assets = nil # Evita loop o doppie esecuzioni

      Array(ids_to_remove).each do |id|
        # Nota: usiamo purge per eliminare definitivamente file e blob
        assets.find_by(id: id)&.purge
      end
    end

    # 2. Gestione AGGIUNTA (APPEND)
    if append_assets.present?
      files_to_attach = append_assets

      # Fondamentale: svuotare prima di attach per evitare ricorsione
      # se attach dovesse innescare un nuovo save callbacks
      self.append_assets = nil

      assets.attach(files_to_attach)
    end
  end
end
