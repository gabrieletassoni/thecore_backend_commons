Rails.application.configure do
  # Installed from `to_prepare` (not `after_initialize`) so the hook is in
  # place *before* `eager_load!` runs -- see
  # `ThecoreBackendCommons::DefaultModuleRegistry.install!` for why that
  # ordering matters. `to_prepare` also re-runs on every class reload in
  # development, so `install!` is idempotent.
  config.to_prepare do
    ThecoreBackendCommons::DefaultModuleRegistry.install!(ApplicationRecord)
  end
end
