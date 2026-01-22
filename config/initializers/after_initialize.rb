Rails.application.configure do
  config.after_initialize do
    Integer.send(:include, FixnumConcern)
    String.send(:include, StringConcern)
    ApplicationCable::Connection.send(:include, CableConnectionConcern)
    # ApplicationRecord.send(:include, ApplicationRecordConcern)
    ApplicationRecord.subclasses.each do |d|
      d.send(:include, BaseApplicationRecordConcern) unless d.name.start_with?("ActiveStorage::", "ActionText::")
    end
  end
end
