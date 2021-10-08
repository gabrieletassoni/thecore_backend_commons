# Rails.application.config.session_store :cookie_store, {
#     :key => "_#{ENV["COMPOSE_PROJECT_NAME"].presence || "localhost"}_session",
#     :domain => :all,
#     :same_site => :none,
#     :secure => :true,
#     :compress => true,
#     :pool_size => 10,
#     :expire_after => 1.year
# }