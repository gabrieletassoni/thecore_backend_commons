Rails.application.config.i18n.available_locales = %w(it en)
Rails.application.config.i18n.default_locale = :en
Rails.application.config.active_storage.configure(
    :Disk,
    root: Rails.root.join("storage")
)