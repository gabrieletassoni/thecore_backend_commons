class AddSenderUserIdToPushMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :push_messages, :sender_user_id, :bigint
    add_index :push_messages, :sender_user_id
  end
end
