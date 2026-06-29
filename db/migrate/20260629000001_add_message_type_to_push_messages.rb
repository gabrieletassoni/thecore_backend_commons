class AddMessageTypeToPushMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :push_messages, :message_type, :string, null: false, default: "communication"
  end
end
