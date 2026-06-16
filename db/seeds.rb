puts "Loading ThecoreBackendCommons seeds"
Thecore::Seed.save_setting :main, :app_name, "The Core by Gabriele Tassoni"

puts "Loading ThecoreBackendCommons SMTP config"
Thecore::Seed.save_setting :smtp, :delivery_method, ""
Thecore::Seed.save_setting :smtp, :from, ""
Thecore::Seed.save_setting :smtp, :address, ""
Thecore::Seed.save_setting :smtp, :port, ""
Thecore::Seed.save_setting :smtp, :domain, ""
Thecore::Seed.save_setting :smtp, :user_name, ""
Thecore::Seed.save_setting :smtp, :password, ""
Thecore::Seed.save_setting :smtp, :authentication, ""
Thecore::Seed.save_setting :smtp, :enable_starttls_auto, ""

puts "Loading ThecoreBackendCommons VAPID config"
require "web-push"
unless ThecoreSettings::Setting.where(ns: :vapid, key: :public_key).where.not(raw: [nil, ""]).exists?
  vapid_key = WebPush.generate_key
  Thecore::Seed.save_setting :vapid, :public_key, vapid_key.public_key
  Thecore::Seed.save_setting :vapid, :private_key, vapid_key.private_key
  puts "  Generated new VAPID key pair"
end
Thecore::Seed.save_setting :vapid, :contact_email, "" unless ThecoreSettings::Setting.where(ns: :vapid, key: :contact_email).exists?
Thecore::Seed.save_setting :vapid, :max_messages_per_subscriber, "500" unless ThecoreSettings::Setting.where(ns: :vapid, key: :max_messages_per_subscriber).exists?