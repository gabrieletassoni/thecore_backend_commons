require_relative "boot"

require "rails/all"

# Stub missing framework config accessors before engines load their initializers.
# thecore_background_jobs references config.action_mailbox and config.action_mailer
# at initializer time; these stubs make those calls no-ops so the dummy app boots
# without the full action_mailbox/action_mailer stack.
stub_class = Class.new do
  def method_missing(name, *args, &block)
    name_s = name.to_s
    return false if name_s.end_with?("?")
    return nil   if name_s.end_with?("=") || args.any? || block
    ivar = :"@_s_#{name_s.gsub(/\W/, "_")}"
    instance_variable_get(ivar) || instance_variable_set(ivar, self.class.new)
  end
  # Do NOT implement to_ary — prevents implicit Array coercion that breaks
  # ActionMailer railtie's @paths.concat(config.action_mailer.mailers_paths).
  def respond_to_missing?(name, *) = name.to_s != "to_ary"
end

Rails::Application::Configuration.prepend(Module.new do
  # Stub action_mailbox (not in rails/all) and assets (sprockets not in bundle).
  %i[action_mailbox assets].each do |fw|
    define_method(fw) { instance_variable_get(:"@_stub_#{fw}") || instance_variable_set(:"@_stub_#{fw}", stub_class.new) }
  end
end)

# Stub ModelDrivenApi.smart_merge — model_driven_api is not in this gem's bundle.
# BaseApplicationRecordConcern (from thecore_backend_commons) calls ::ModelDrivenApi.smart_merge
# in its included block when models are initialized in after_initialize.
module ModelDrivenApi
  def self.smart_merge(base, additions)
    base.merge(additions) { |_, a, b| a.is_a?(Array) && b.is_a?(Array) ? (a + b).uniq : b }
  end
end

Bundler.require(*Rails.groups)
require "thecore_backend_commons"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.eager_load = false

    initializer "dummy.preload_stubs", before: :run_load_hooks do
      ActiveSupport.on_load(:active_record) do
        extend(Module.new do
          def has_rich_text(*names)
            names.each { |name| define_method(name) { nil } }
          end
        end) unless respond_to?(:has_rich_text)
      end

      require File.expand_path("../app/models/application_record", __dir__)
      require File.expand_path("../app/models/user", __dir__)
      require File.expand_path("../app/models/ability", __dir__)
      require File.expand_path("../app/channels/application_cable/connection", __dir__)
    end
  end
end
