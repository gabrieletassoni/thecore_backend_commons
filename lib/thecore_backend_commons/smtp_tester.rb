# frozen_string_literal: true

module ThecoreBackendCommons
  # Sends a test email using the SMTP settings from ThecoreSettings.
  # Usable from the Rails console or via the rake task.
  #
  # From rails console:
  #   ThecoreBackendCommons::SmtpTester.call("you@example.com")
  #
  # From the shell:
  #   rails thecore_backend_commons:smtp:test[you@example.com]
  class SmtpTester
    def self.call(recipient = nil)
      new(recipient).call
    end

    def initialize(recipient = nil)
      @recipient = recipient.presence ||
                   ThecoreSettings::Setting.find_by(ns: :mytask, key: :default_email)&.raw
    end

    def call
      validate!
      print_settings
      send_mail
    end

    private

    def validate!
      raise ArgumentError, "No recipient given and mytask.default_email is not configured." if @recipient.blank?
      raise ArgumentError, "smtp.address is not configured in ThecoreSettings." if opts[:address].blank?
    end

    def print_settings
      puts "SMTP settings:"
      puts "  address:             #{opts[:address]}"
      puts "  port:                #{opts[:port]}"
      puts "  domain:              #{opts[:domain].inspect}"
      puts "  user_name:           #{opts[:user_name].inspect}"
      puts "  authentication:      #{opts[:authentication].inspect}"
      puts "  tls:                 #{opts[:tls]}"
      puts "  enable_starttls_auto:#{opts[:enable_starttls_auto]}"
      puts "  from:                #{SmtpConfig.setting(:from).inspect}"
      puts ""
      puts "Sending test email to: #{@recipient}"
    end

    def send_mail
      from_address = SmtpConfig.setting(:from).presence || "noreply@mytask.local"
      delivery_opts = opts

      mail = Mail.new do
        from    from_address
        to      delivery_opts[:address] # placeholder; overridden below
        subject "[MyTask] SMTP test — #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
        body    "This is an automated SMTP connectivity test sent from MyTask.\n\n" \
                "If you received this message, the SMTP configuration is working correctly.\n\n" \
                "Settings used:\n" \
                "  address: #{delivery_opts[:address]}\n" \
                "  port: #{delivery_opts[:port]}\n" \
                "  tls: #{delivery_opts[:tls]}\n" \
                "  auth: #{delivery_opts[:authentication].inspect}"
      end
      mail.to = @recipient
      mail.delivery_method(:smtp, delivery_opts)
      mail.deliver!
      puts "OK: email delivered successfully."
      true
    rescue StandardError => e
      puts "ERROR: #{e.class}: #{e.message}"
      false
    end

    def opts
      @opts ||= SmtpConfig.delivery_options
    end
  end
end
