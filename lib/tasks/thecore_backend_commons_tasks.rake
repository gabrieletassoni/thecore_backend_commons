namespace :thecore_backend_commons do
  namespace :smtp do
    desc "Send a test email using ThecoreSettings SMTP config. " \
         "Usage: rails thecore_backend_commons:smtp:test[recipient@example.com] " \
         "(omit argument to use mytask.default_email)"
    task :test, [:recipient] => :environment do |_t, args|
      success = ThecoreBackendCommons::SmtpTester.call(args[:recipient])
      exit 1 unless success
    end
  end
end
