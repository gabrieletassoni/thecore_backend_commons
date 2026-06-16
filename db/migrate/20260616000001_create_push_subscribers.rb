class CreatePushSubscribers < ActiveRecord::Migration[7.2]
  def change
    create_table :push_subscribers do |t|
      t.bigint :user_id, null: false
      t.text :endpoint, null: false
      t.string :p256dh
      t.string :auth
      t.string :user_agent
      t.datetime :expired_at
      t.timestamps
    end
    add_index :push_subscribers, :endpoint, unique: true
    add_index :push_subscribers, :user_id
  end
end
