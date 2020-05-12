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
        # In development be sure to load all the namespaces
        # in order to have working reflection and meta-programming.
        if Rails.env.development?
            Rails.configuration.eager_load_namespaces.each(&:eager_load!) if Rails.version.to_i == 5 #Rails 5
            Zeitwerk::Loader.eager_load_all if Rails.version.to_i >= 6 #Rails 6
        end

        # include the extensions
        ActiveRecord::Base.send(:include, ActiveRecordExtensions)
        Integer.send(:include, FixnumConcern)
        String.send(:include, StringConcern)
        RailsAdmin::Config::Actions::Export.send(:include, ExportConcern)
        RailsAdmin::Config::Actions::BulkDelete.send(:include, BulkDeleteConcern)
        User.send(:include, ThecoreBackendCommonsUser)
    end
end