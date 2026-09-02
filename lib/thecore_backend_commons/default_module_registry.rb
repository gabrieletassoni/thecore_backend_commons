module ThecoreBackendCommons
  # Shared registry other gems use to register "default" modules that get
  # `include`d automatically into every `ApplicationRecord` subclass, as it
  # is defined -- not via a post-boot scan of `ApplicationRecord.subclasses`.
  #
  # This exists so multiple gems (`model_driven_api`, `thecore_ui_rails_admin`,
  # ...) can each contribute default model behavior (API serialization shape,
  # RailsAdmin config, ...) through ONE shared `ApplicationRecord.inherited`
  # hook instead of each gem independently overriding `inherited` itself.
  # See ADR 0001/0002 (`vendor/external/thecore/docs/adr/` in the host app).
  #
  # == Usage
  #
  #   ThecoreBackendCommons::DefaultModuleRegistry.register(
  #     MyDefaultModule,
  #     applies_to: ->(klass) { klass.table_exists? rescue false }
  #   )
  #
  # `applies_to` defaults to "every subclass" (`->(_klass) { true }`) when
  # omitted. Registered modules are `include`d, in registration order, into
  # every `ApplicationRecord` subclass for which `applies_to` returns true,
  # at the moment the subclass is defined -- see `InheritedHook` below.
  #
  # `MyDefaultModule` should normally be an `ActiveSupport::Concern` with an
  # `included do ... end` block, so its default methods/callbacks/DSL calls
  # land as *own* behavior on each model class (see ADR 0001's consequences
  # section -- `model_driven_api`'s introspection depends on this).
  #
  # == Idempotency
  #
  # - Calling `.register` twice with the *same* module object is a no-op the
  #   second time -- it will not be applied twice to any subclass.
  # - `.apply_to` never re-includes a module a class already has in its
  #   ancestor chain (e.g. an STI subclass that already inherited it from its
  #   base class), so STI subclasses are never double-included.
  # - `.apply_to` never applies anything to an abstract class
  #   (`klass.abstract_class?`) -- most importantly `ApplicationRecord`
  #   itself (`primary_abstract_class`), which never receives default
  #   modules through this mechanism since `ApplicationRecord.inherited` only
  #   fires for classes that inherit *from* `ApplicationRecord`, never for
  #   `ApplicationRecord`'s own definition.
  module DefaultModuleRegistry
    Entry = Struct.new(:mod, :applies_to)
    private_constant :Entry

    # Prepended onto `ApplicationRecord.singleton_class` (see `.install!`)
    # so that every subsequent subclass definition applies the registry.
    #
    # Calls `super` first so it composes correctly with ActiveRecord's own
    # `inherited` (which sets up `base_class`, STI bookkeeping, ...) and with
    # any other gem's pre-existing `inherited` override further up the
    # singleton-class ancestor chain.
    module InheritedHook
      def inherited(subclass)
        super
        ThecoreBackendCommons::DefaultModuleRegistry.apply_to(subclass)
      end
    end

    class << self
      # Registers +mod+ so it gets `include`d into every matching
      # `ApplicationRecord` subclass defined from now on. Returns +mod+.
      #
      # +applies_to+ is a 1-arity callable invoked with the candidate class;
      # only classes for which it returns truthy receive +mod+.
      #
      # Registering the same module object again is a no-op -- the original
      # registration (and its original `applies_to`) is kept.
      def register(mod, applies_to: ->(_klass) { true })
        entries << Entry.new(mod, applies_to) unless registered?(mod)
        mod
      end

      # True if +mod+ has already been registered.
      def registered?(mod)
        entries.any? { |entry| entry.mod.equal?(mod) }
      end

      # Applies every registered module whose `applies_to` predicate matches
      # +klass+, in registration order. No-op for abstract classes. Never
      # re-includes a module +klass+ already has in its ancestor chain.
      #
      # Called automatically by `InheritedHook` -- only call directly from
      # application/test code that needs to (re-)apply defaults to a class
      # defined before the registry/hook was set up.
      def apply_to(klass)
        return klass if klass.abstract_class?

        entries.each do |entry|
          next unless entry.applies_to.call(klass)
          next if klass.include?(entry.mod)

          klass.include(entry.mod)
        end

        klass
      end

      # Installs `InheritedHook` onto +base_class+'s singleton class so every
      # subsequently-defined subclass triggers `.apply_to`. Idempotent --
      # safe to call on every `to_prepare` cycle in development.
      #
      # Must run before any subclass of +base_class+ is defined (i.e. before
      # eager loading), which is why the host initializer installs it from
      # `config.to_prepare` rather than `config.after_initialize` -- Rails
      # runs `to_prepare` callbacks *before* `eager_load!`, while
      # `after_initialize` runs *after* it (see
      # `Rails::Application::Finisher`). Installing from `after_initialize`
      # would miss every subclass already loaded by eager loading in
      # production.
      def install!(base_class)
        return base_class if base_class.singleton_class.ancestors.include?(InheritedHook)

        base_class.singleton_class.prepend(InheritedHook)
        base_class
      end

      # Test helper: clears all registrations. Not intended for production
      # use -- does not uninstall `InheritedHook` from any class it was
      # already installed on, and does not un-include modules already
      # included into existing classes.
      def reset!
        @entries = []
      end

      private

      def entries
        @entries ||= []
      end
    end
  end
end
