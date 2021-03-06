$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "thecore_backend_commons/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "thecore_backend_commons"
  spec.version     = ThecoreBackendCommons::VERSION
  spec.authors     = ["Gabriele Tassoni"]
  spec.email       = ["gabriele.tassoni@gmail.com"]
  spec.homepage    = "https://github.com/gabrieletassoni/thecore_backend_commons"
  spec.summary     = "Thecore 2 foundations for the Web UI Backend."
  spec.description = "Wrapper to keep all the common libraries and setups needed by Thecore UI Backend(s)."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency 'thecore_auth_commons', '~> 2.1'
  # Rails
  spec.add_dependency 'rails-i18n', "~> 6.0"
  spec.add_dependency 'devise-i18n', "~> 1.5"
  # Auto Locale
  # A gem which helps you detect the users preferred language, as sent by the "Accept-Language" HTTP header.
  # https://github.com/iain/http_accept_language
  spec.add_dependency 'http_accept_language', "~> 2.1"
  spec.add_dependency "rails_admin_settings", "~> 1.5"
  # Gem to import from CSV, XLS, XLSX, etc.
  spec.add_dependency "roo", "~> 2.8"
  spec.add_dependency "roo-xls", "~> 1.2"
end
