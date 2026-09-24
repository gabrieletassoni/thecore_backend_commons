require "ostruct"
require "web-push" # gem for VAPID web push (pushpad/web-push, actively maintained)
require "thecore_auth_commons"
require "thecore_background_jobs"
require "rails-i18n"
require "devise-i18n"
require "http_accept_language"
require "roo"
require "roo-xls"
require "active_storage_validations"
require "ulid"
require "csv"
require "seed_dump"
require "deep_merge/rails_compat"

require "thecore_backend_commons/version"
require "thecore_backend_commons/engine"
require "thecore_backend_commons/smtp_config"
require "thecore_backend_commons/smtp_tester"
require "thecore_backend_commons/push_notification_service"
require "thecore_backend_commons/default_module_registry"

module ThecoreBackendCommons
  # Deep-merges +dest+ into +src+ (mutating and returning +src+), extending existing arrays
  # instead of replacing them — the way json_attrs are composed across concerns.
  # Lives here, not in model_driven_api: model_driven_api depends on this gem, so this gem's own
  # TimeZoneAware / BaseApplicationRecordConcern (and gems built on it) calling
  # ::ModelDrivenApi.smart_merge crashed with NameError in any app without model_driven_api.
  # ModelDrivenApi.smart_merge now delegates here.
  def self.smart_merge(src, dest)
    src.deeper_merge!(dest, extend_existing_arrays: true, merge_hash_arrays: true)
    src
  end
end
