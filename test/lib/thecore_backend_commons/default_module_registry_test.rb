require "test_helper"

# NOTE on test design:
#
# 1. `ApplicationRecord.inherited` fires *before* the new subclass's own
#    body executes (a general Ruby property, not specific to this gem --
#    `self.abstract_class = true`/`self.table_name = ...` lines inside a
#    `class Foo < ApplicationRecord ... end` body run *after* Ruby has
#    already invoked `ApplicationRecord.inherited(Foo)`). Every fixture
#    class below that needs a stable, already-known property at `inherited`
#    time (name, ancestry) is therefore either defined with the plain
#    `class Foo < Bar; end` keyword form (whose constant name *is* bound
#    before `inherited` fires, unlike `Class.new(Bar)` assigned to a
#    constant afterwards), or filtered on ancestry (`klass < SomeMarker`),
#    which is correct at `inherited` time regardless of naming.
#
# 2. Anonymous AR classes (`Class.new(ApplicationRecord)`) are immediately
#    given a real constant name via `anon_model` below. Without a name,
#    ActiveRecord's own `#inspect` (invoked by Minitest when rendering a
#    failed assertion) blows up with `ArgumentError: Class name cannot be
#    blank`, turning any incidental test failure into a confusing crash.
#
# 3. Registrations and fixture class definitions are deliberately ordered
#    top-to-bottom: a module is always registered *before* the fixture
#    class(es) it should apply to are defined, mirroring real usage (and
#    demonstrating the "not a post-boot scan" requirement -- nothing here
#    re-scans ApplicationRecord.subclasses after the fact).
#
# 4. Each scenario that counts `included` calls uses its own dedicated
#    marker base class and an ancestry-scoped `applies_to` (`klass <
#    Marker`), so unrelated `Class.new(ApplicationRecord)` fixtures created
#    by *other* tests in this file can never accidentally match its
#    predicate and inflate its counter.
module ThecoreBackendCommons
  def self.anon_model(superclass, name)
    Class.new(superclass).tap { |k| const_set(name, k) }
  end

  # --- Shared counters, read by the test methods below --------------------
  DefaultModuleRegistryTestCounters = Hash.new(0)
  DefaultModuleRegistryTestCounters[:other_gem_hook_fired] = false

  # --- Fixtures for the "applies_to filtering" scenario --------------------
  DefaultModuleRegistryMatchingModule = Module.new do
    extend ActiveSupport::Concern
    included do
      cattr_accessor :matching_default_applied
      self.matching_default_applied = true
    end
  end

  DefaultModuleRegistryNonMatchingModule = Module.new do
    extend ActiveSupport::Concern
  end

  DefaultModuleRegistry.register(
    DefaultModuleRegistryMatchingModule,
    applies_to: ->(klass) { klass.name == "ThecoreBackendCommonsMatchesFilterModel" }
  )
  DefaultModuleRegistry.register(
    DefaultModuleRegistryNonMatchingModule,
    applies_to: ->(_klass) { false }
  )

  # --- Fixtures for the "registered before subclass exists" scenario ------
  DefaultModuleRegistryBasicModule = Module.new do
    extend ActiveSupport::Concern
    included do
      cattr_accessor :basic_default_applied
      self.basic_default_applied = true
    end
  end
  DefaultModuleRegistry.register(DefaultModuleRegistryBasicModule)

  # --- Fixtures for abstract-class exclusion (primary_abstract_class) -----
  # ApplicationRecord itself is `primary_abstract_class`; it must never
  # receive default modules, since `ApplicationRecord.inherited` only fires
  # for classes inheriting *from* ApplicationRecord, never for
  # ApplicationRecord's own (already-loaded-at-boot) definition. `apply_to`
  # additionally guards on `klass.abstract_class?` directly, which this
  # covers when called explicitly against an already-abstract class.
  DefaultModuleRegistryAbstractCheckModule = Module.new do
    extend ActiveSupport::Concern
  end
  DefaultModuleRegistry.register(DefaultModuleRegistryAbstractCheckModule, applies_to: ->(_klass) { true })

  # --- Fixtures for the "double registration" scenario ---------------------
  # Scoped to its own marker base (via strict `<`, excluding the marker
  # itself) so only subclasses created inside its own test can ever match.
  class ThecoreBackendCommonsDoubleRegisterMarkerBase < ApplicationRecord
    self.abstract_class = true
  end

  DefaultModuleRegistryDoubleRegisterModule = Module.new
  DefaultModuleRegistryDoubleRegisterModule.define_singleton_method(:included) do |base|
    super(base)
    DefaultModuleRegistryTestCounters[:double_register_calls] += 1
  end
  DefaultModuleRegistry.register(
    DefaultModuleRegistryDoubleRegisterModule,
    applies_to: ->(klass) { klass < ThecoreBackendCommonsDoubleRegisterMarkerBase }
  )
  DefaultModuleRegistry.register( # deliberate duplicate registration
    DefaultModuleRegistryDoubleRegisterModule,
    applies_to: ->(klass) { klass < ThecoreBackendCommonsDoubleRegisterMarkerBase }
  )

  # --- Fixtures for the STI scenario ----------------------------------------
  # Module registered *before* the STI base class is defined, so the base
  # gets it at `inherited` time; the STI child then inherits it via ancestry
  # rather than being separately (re-)included.
  DefaultModuleRegistrySTIModule = Module.new
  DefaultModuleRegistrySTIModule.define_singleton_method(:included) do |base|
    super(base)
    DefaultModuleRegistryTestCounters[:sti_include_calls] += 1
  end
  DefaultModuleRegistry.register(
    DefaultModuleRegistrySTIModule,
    applies_to: ->(klass) { klass <= ThecoreBackendCommonsStiBase }
  )

  class ThecoreBackendCommonsStiBase < ApplicationRecord
  end

  class ThecoreBackendCommonsStiChild < ThecoreBackendCommonsStiBase
  end

  # --- Fixtures for the "super composition" scenario ------------------------
  # Simulates another gem that already patched `inherited` further down the
  # chain (on an intermediate class), closer to the eventual subclass than
  # ours (installed on ApplicationRecord itself) -- proving our hook's
  # `super` call correctly propagates the chain instead of swallowing it.
  class ThecoreBackendCommonsSuperCompositionBase < ApplicationRecord
    self.abstract_class = true

    module OtherGemInheritedHook
      def inherited(subclass)
        ThecoreBackendCommons::DefaultModuleRegistryTestCounters[:other_gem_hook_fired] = true
        super
      end
    end
    singleton_class.prepend(OtherGemInheritedHook)
  end

  DefaultModuleRegistrySuperCompositionModule = Module.new do
    extend ActiveSupport::Concern
  end
  DefaultModuleRegistry.register(
    DefaultModuleRegistrySuperCompositionModule,
    applies_to: ->(klass) { klass < ThecoreBackendCommonsSuperCompositionBase }
  )

  class DefaultModuleRegistryTest < ActiveSupport::TestCase
    test "the InheritedHook is installed on ApplicationRecord by boot time (config.to_prepare)" do
      assert_includes ApplicationRecord.singleton_class.ancestors, DefaultModuleRegistry::InheritedHook
    end

    test "install! is idempotent -- calling it again does not re-prepend the hook" do
      DefaultModuleRegistry.install!(ApplicationRecord)
      DefaultModuleRegistry.install!(ApplicationRecord)

      count = ApplicationRecord.singleton_class.ancestors.count { |a| a == DefaultModuleRegistry::InheritedHook }
      assert_equal 1, count
    end

    test "a module registered before any subclass exists is included into a subsequently-defined subclass" do
      klass = ThecoreBackendCommons.anon_model(ApplicationRecord, :RegisteredBeforeSubclassModel)

      assert klass.include?(DefaultModuleRegistryBasicModule)
      assert klass.basic_default_applied
    end

    test "applies_to excludes a class the predicate does not match" do
      matching = ThecoreBackendCommons.anon_model(ApplicationRecord, :UnrelatedAnonymousModel)

      refute matching.include?(DefaultModuleRegistryMatchingModule),
        "an anonymous class should not match the name-based predicate"
    end

    test "applies_to includes the matching named class and excludes a non-matching one" do
      assert ThecoreBackendCommonsMatchesFilterModel.include?(DefaultModuleRegistryMatchingModule)
      assert ThecoreBackendCommonsMatchesFilterModel.matching_default_applied

      refute ThecoreBackendCommonsDoesNotMatchFilterModel.include?(DefaultModuleRegistryMatchingModule)
      refute ThecoreBackendCommonsMatchesFilterModel.include?(DefaultModuleRegistryNonMatchingModule)
    end

    test "ApplicationRecord (primary_abstract_class) never receives registered default modules" do
      assert ApplicationRecord.abstract_class?
      refute ApplicationRecord.include?(DefaultModuleRegistryAbstractCheckModule)

      # Explicit call, not just the boot-time inherited path: apply_to must
      # remain a no-op even when invoked directly against an abstract class.
      DefaultModuleRegistry.apply_to(ApplicationRecord)
      refute ApplicationRecord.include?(DefaultModuleRegistryAbstractCheckModule)
    end

    test "STI: the module lands once on the base class and is inherited (not re-included) by the child" do
      assert ThecoreBackendCommonsStiBase.include?(DefaultModuleRegistrySTIModule)
      assert ThecoreBackendCommonsStiChild.include?(DefaultModuleRegistrySTIModule)

      assert_equal ThecoreBackendCommonsStiBase, ThecoreBackendCommonsStiChild.base_class
      assert_not_equal ThecoreBackendCommonsStiChild, ThecoreBackendCommonsStiChild.base_class

      assert_equal 1, DefaultModuleRegistryTestCounters[:sti_include_calls],
        "the module's `included` hook must fire exactly once (for the STI base), never again for the child"
    end

    test "inherited override calls super: a pre-existing inherited hook (simulating another gem's) still fires" do
      subclass = ThecoreBackendCommons.anon_model(ThecoreBackendCommonsSuperCompositionBase, :SuperCompositionChild)

      assert DefaultModuleRegistryTestCounters[:other_gem_hook_fired],
        "the pre-existing (simulated third-party) inherited hook must still run"
      assert subclass.include?(DefaultModuleRegistrySuperCompositionModule),
        "our registry must still apply after composing with the pre-existing hook's super chain"
      # ThecoreBackendCommonsSuperCompositionBase is itself abstract, so
      # `subclass` starts its own STI hierarchy (base_class == itself) --
      # this only resolves correctly if `super` really ran ActiveRecord's
      # own `inherited` (which computes `base_class`) rather than being
      # swallowed by either hook.
      assert_equal subclass, subclass.base_class
    end

    test "registering the same module object twice only includes it once per matching subclass" do
      klass = ThecoreBackendCommons.anon_model(ThecoreBackendCommonsDoubleRegisterMarkerBase, :DoubleRegisterChild)

      assert klass.include?(DefaultModuleRegistryDoubleRegisterModule)
      assert_equal 1, DefaultModuleRegistryTestCounters[:double_register_calls]
      assert_equal 1, klass.ancestors.count { |a| a == DefaultModuleRegistryDoubleRegisterModule }
    end

    test "register returns the module and registered? reflects registration state" do
      mod = Module.new
      refute DefaultModuleRegistry.registered?(mod)

      returned = DefaultModuleRegistry.register(mod)

      assert_equal mod, returned
      assert DefaultModuleRegistry.registered?(mod)
    end

    test "apply_to returns the class it was given" do
      klass = ThecoreBackendCommons.anon_model(ApplicationRecord, :ApplyToReturnValueModel)
      assert_equal klass, DefaultModuleRegistry.apply_to(klass)
    end
  end
end

class ThecoreBackendCommonsMatchesFilterModel < ApplicationRecord
end

class ThecoreBackendCommonsDoesNotMatchFilterModel < ApplicationRecord
end
