class AddTimeZoneColumnsToPushMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :push_messages, :sent_at_time_zone, :string
    add_column :push_messages, :received_at_time_zone, :string
    add_column :push_messages, :read_at_time_zone, :string
  end
end
