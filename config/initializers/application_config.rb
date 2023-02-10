Rails.application.config.active_storage.configure :Disk, root: Rails.root.join("storage")
Rails.application.config.action_mailer.delivery_method = :smtp
