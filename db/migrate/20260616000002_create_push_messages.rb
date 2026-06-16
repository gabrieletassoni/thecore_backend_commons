class CreatePushMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :push_messages do |t|
      t.bigint :push_subscriber_id, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :url
      t.string :icon
      t.datetime :sent_at
      t.datetime :received_at
      t.datetime :read_at
      t.timestamps
    end
    add_index :push_messages, :push_subscriber_id
  end
end
