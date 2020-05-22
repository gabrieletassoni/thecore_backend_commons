Rails.application.configure do
    # I18n
    config.i18n.available_locales = %w(it en)
    config.i18n.default_locale = :it
    config.time_zone = 'Rome'
    # Active Storage
    config.active_storage.configure(
        :Disk,
        root: Rails.root.join("storage")
    )
    # AFTER INITIALIZE Good place to load things that must have a bit of initialization 
    # setup on order to work (and not be overrided).    
    config.after_initialize do
        # include the extensions
        ActiveRecord::Base.send(:include, ActiveRecordExtensions)
        Integer.send(:include, FixnumConcern)
        String.send(:include, StringConcern)
        User.send(:include, ThecoreBackendCommonsUser)
    end
end