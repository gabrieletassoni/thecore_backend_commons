Rails.application.config.relative_url_root = ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/")
Rails.application.config.assets.prefix = "#{ENV.fetch("RAILS_RELATIVE_URL_ROOT", "")}/assets".gsub('//', '/')

Rails.application.config.active_storage.configure :Disk, root: Rails.root.join("storage")
Rails.application.config.active_storage.routes_prefix = ENV.fetch("RAILS_RELATIVE_URL_ROOT", "")

Rails.application.config.action_mailer.delivery_method = :smtp

Rails.application.config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/, /file:\/\/*/, 'file://', nil]

# Every Thecore app ships a dedicated Sidekiq worker service alongside the web backend (see
# thecore_devcontainer's docker-compose.yml) — this gem already hard-requires the sidekiq gems
# and mounts Sidekiq::Web unconditionally (thecore_background_jobs), so ActiveJob should actually
# route through it rather than defaulting to Rails' in-process :async, which silently drops any
# job in flight when its process restarts. Production only: :async remains the default in
# development/test so neither requires a reachable Redis. See docs/adr/0001, CONTEXT.md.
Rails.application.config.active_job.queue_adapter = :sidekiq if Rails.env.production?
