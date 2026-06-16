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

require "thecore_backend_commons/version"
require "thecore_backend_commons/engine"
require "thecore_backend_commons/smtp_config"
require "thecore_backend_commons/smtp_tester"
require "thecore_backend_commons/push_notification_service"

module ThecoreBackendCommons
end
