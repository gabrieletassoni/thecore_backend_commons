Rails.application.configure do

    config.after_initialize do
        Integer.send(:include, FixnumConcern)
        String.send(:include, StringConcern)
        ApplicationCable::Connection.send(:include, CableConnectionConcern)
        ApplicationRecord.send(:include, ApplicationRecordConcern)
    end
end