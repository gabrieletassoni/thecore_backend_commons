Rails.application.configure do
    config.after_initialize do
        Integer.send(:include, FixnumConcern)
        String.send(:include, StringConcern)
    end
end