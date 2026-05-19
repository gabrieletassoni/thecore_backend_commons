# frozen_string_literal: true

module ThecoreBackendCommons
  # Reads SMTP settings from ThecoreSettings (ns: :smtp) and builds the
  # delivery_options hash for ActionMailer / Net::SMTP.
  #
  # Port 465  → SMTPS (implicit TLS from the first byte): tls: true.
  # Port 587  → STARTTLS (plain connection upgraded after banner): enable_starttls_auto.
  # The two modes are mutually exclusive; mixing them causes a ReadTimeout.
  module SmtpConfig
    FALSY_STRINGS = %w[false f 0 no].freeze

    module_function

    def setting(key)
      ThecoreSettings::Setting.find_by(ns: :smtp, key: key)&.raw
    end

    def delivery_options
      auth = setting(:authentication)
      auth = nil if auth.blank? || auth == 'none'
      port = setting(:port)&.to_i || 587
      smtps = port == 465
      opts = {
        address: setting(:address),
        port: port,
        domain: setting(:domain),
        user_name: setting(:user_name),
        password: setting(:password),
        authentication: auth&.to_sym,
        tls: smtps,
        enable_starttls_auto: !smtps && FALSY_STRINGS.exclude?(setting(:enable_starttls_auto).to_s.downcase.strip)
      }
      opts.transform_values! { |v| v.is_a?(String) ? v.strip.presence : v }
      unless opts[:authentication]
        opts.delete(:user_name)
        opts.delete(:password)
      end
      opts.compact
    end
  end
end
