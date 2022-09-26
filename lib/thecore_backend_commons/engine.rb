module ThecoreBackendCommons
  class Engine < ::Rails::Engine
    initializer "thecore_backend_commons.assets.precompile" do |app|    
      # Here you can place the assets provided by this engine in order for them to be precompiled in production and JIT 
      # compiled in development.
      # As an example:
      # app.config.assets.precompile += %w( overrides.css )
      # app.config.assets.precompile += %w( android-chrome-192x192.png )
      if ENV['COMPOSE_PROJECT_NAME'].present? && ENV['BASE_DOMAIN'].present?
        puts "WHITE LABEL is in place for vendor/custombuilds/#{ENV['COMPOSE_PROJECT_NAME']}.#{ENV['BASE_DOMAIN']}/deltas/app"
        # Somewhat white label support
        app.config.autoload_paths += %W( 
          vendor/custombuilds/#{ENV['COMPOSE_PROJECT_NAME']}.#{ENV['BASE_DOMAIN']}/deltas/app/models
          vendor/custombuilds/#{ENV['COMPOSE_PROJECT_NAME']}.#{ENV['BASE_DOMAIN']}/deltas/app/jobs 
          vendor/custombuilds/#{ENV['COMPOSE_PROJECT_NAME']}.#{ENV['BASE_DOMAIN']}/deltas/app/mailers 
          vendor/custombuilds/#{ENV['COMPOSE_PROJECT_NAME']}.#{ENV['BASE_DOMAIN']}/deltas/db 
        )
      end
    end
    initializer 'thecore_backend_commons.add_to_thecore_engines_list' do |app|
      Thecore::Base.thecore_engines << self.class
    end
    initializer 'thecore_backend_commons.add_to_migrations' do |app|
      # Adds the list of Thecore Engines, so to manage seeds loading, i.e.:
      # Thecore::Base.thecore_engines.each { |engine| engine.load_seed }
      Thecore::Base.thecore_engines << self.class
      unless app.root.to_s.match root.to_s
        # APPEND TO MAIN APP MIGRATIONS FROM THIS GEM
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end
  end
end
