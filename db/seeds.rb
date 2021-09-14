puts "Loading ThecoreBackendCommons seeds"
Settings.app_name = "The Core by Gabriele Tassoni"

Thecore::Seed.save_setting :smtp, :delivery_method, nil
Thecore::Seed.save_setting :smtp, :from, nil
Thecore::Seed.save_setting :smtp, :address, nil
Thecore::Seed.save_setting :smtp, :port, nil
Thecore::Seed.save_setting :smtp, :domain, nil
Thecore::Seed.save_setting :smtp, :user_name, nil
Thecore::Seed.save_setting :smtp, :password, nil
Thecore::Seed.save_setting :smtp, :authentication, nil
Thecore::Seed.save_setting :smtp, :enable_starttls_auto, nil