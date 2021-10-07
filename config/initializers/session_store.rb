Rails.application.config.session_store :cookie_store, {
    :key => "_#{ENV["COMPOSE_PROJECT_NAME"].presence || "development"}_session",
    :domain => :all,
    :same_site => :none,
    :secure => :true,
    :tld_length => 3
}