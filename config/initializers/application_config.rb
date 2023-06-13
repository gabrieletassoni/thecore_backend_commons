Rails.application.config.active_storage.configure :Disk, root: Rails.root.join("storage")
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_cable.allowed_request_origins = [ ENV["FRONTEND_URL"].presence || /http:\/\/*/, ENV["BACKEND_URL"].presence || /http:\/\/*/, "https://localhost:8100" ].uniq
