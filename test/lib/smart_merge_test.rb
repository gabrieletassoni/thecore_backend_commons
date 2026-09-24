require "test_helper"

# ThecoreBackendCommons.smart_merge composes json_attrs across concerns. It lives here (not in
# model_driven_api, which depends on this gem) so that this gem's own TimeZoneAware and
# BaseApplicationRecordConcern — and every sibling gem built on it — can use it without
# depending upward. ModelDrivenApi.smart_merge delegates to it, so the semantics must stay
# identical to the original deep_merge-based implementation.
class SmartMergeTest < ActiveSupport::TestCase
  test "extends existing arrays instead of replacing them" do
    src = { methods: [:a], except: [:x] }
    ThecoreBackendCommons.smart_merge(src, { methods: [:b] })
    assert_equal [:a, :b], src[:methods]
    assert_equal [:x], src[:except]
  end

  test "deep-merges nested hashes" do
    src = { include: { user: { only: [:id] } } }
    ThecoreBackendCommons.smart_merge(src, { include: { user: { only: [:email] }, site: { only: [:id] } } })
    assert_equal({ user: { only: [:id, :email] }, site: { only: [:id] } }, src[:include])
  end

  test "mutates and returns src, like ModelDrivenApi.smart_merge always did" do
    src = { methods: [:a] }
    assert_same src, ThecoreBackendCommons.smart_merge(src, { methods: [:b] })
  end

  test "is a no-op when merging an empty hash" do
    assert_equal({ except: [] }, ThecoreBackendCommons.smart_merge({ except: [] }, {}))
  end
end
