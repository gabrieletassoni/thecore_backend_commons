require 'thecore_auth_commons'
require 'devise-i18n'
require 'http_accept_language'
require 'rails-i18n'
require 'thecore_settings'

require 'patches/thecore'

require 'roo'
require 'roo-xls'

require "thecore_backend_commons/engine"

module ThecoreBackendCommons
  # Your code goes here...
end

module Thecore
  class Seed
    def self.save_setting ns, setting, value
      puts "Saving setting if nil #{ns}: #{setting} = #{value}"
      if Settings.ns(ns)[setting].blank?
        Settings.ns(ns)[setting] if value.blank?
        Settings.ns(ns)[setting] = value unless value.blank?
      end
    end
  end
end
