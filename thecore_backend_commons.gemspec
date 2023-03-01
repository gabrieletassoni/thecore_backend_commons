$:.push File.expand_path("lib", __dir__)

require_relative "lib/thecore_backend_commons/version"

Gem::Specification.new do |spec|
  spec.name        = "thecore_backend_commons"
  spec.version     = ThecoreBackendCommons::VERSION
  spec.authors     = ["Gabriele Tassoni"]
  spec.email       = ["g.tassoni@bancolini.com"]
  spec.homepage    = "https://github.com/gabrieletassoni/thecore_backend_commons"
  spec.summary     = "Thecore 3 foundations for the Web UI Backend."
  spec.description = "Wrapper to keep all the common libraries and setups needed by Thecore UI Backend(s)."
  
  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gabrieletassoni/thecore_backend_commons"
  spec.metadata["changelog_uri"] = "https://github.com/gabrieletassoni/thecore_backend_commons/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency 'thecore_auth_commons', '~> 3.0'
  spec.add_dependency 'thecore_background_jobs', '~> 3.0'
  # Rails
  # https://github.com/svenfuchs/rails-i18n
  spec.add_dependency 'rails-i18n', "~> 7.0"
  # https://github.com/tigrish/devise-i18n
  spec.add_dependency 'devise-i18n', "~> 1.10"
  # Auto Locale
  # A gem which helps you detect the users preferred language, as sent by the "Accept-Language" HTTP header.
  # https://github.com/iain/http_accept_language
  spec.add_dependency 'http_accept_language', "~> 2.1"
  # Gem to import from CSV, XLS, XLSX, etc.
  # https://github.com/roo-rb/roo
  spec.add_dependency "roo", "~> 2.9"
  # https://github.com/roo-rb/roo-xls
  spec.add_dependency "roo-xls", "~> 1.2"
  # https://github.com/igorkasyanchuk/active_storage_validations
  spec.add_dependency 'active_storage_validations', "~> 1.0"
  # https://github.com/rafaelsales/ulid
  spec.add_dependency 'ulid', '~> 1.3'
end
