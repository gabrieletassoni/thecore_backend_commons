require 'thecore_auth_commons'
require 'devise-i18n'
require 'http_accept_language'
require 'rails-i18n'
require 'thecore_settings'

require 'patches/thecore'
require 'concerns/thecore_backend_commons_user'

require 'roo'
require 'roo-xls'

require "thecore_backend_commons/engine"

module ThecoreBackendCommons
  # Your code goes here...
end

module Thecore
  class Seed
    def self.save_setting ns, setting, value
      Settings.ns(ns)[setting] = value if Settings.ns(ns)[setting].blank?
    end
  end
end
