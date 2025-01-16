Rails.application.config.relative_url_root = ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/")
Rails.application.config.assets.prefix = "#{ENV.fetch("RAILS_RELATIVE_URL_ROOT", "")}/assets".gsub('//', '/')

Rails.application.config.active_storage.configure :Disk, root: Rails.root.join("storage")
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/, /file:\/\/*/, 'file://', nil]