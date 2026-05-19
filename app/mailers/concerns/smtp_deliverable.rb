# frozen_string_literal: true

# Include in any ActionMailer subclass to wire up SMTP delivery from
# ThecoreSettings at send time (no application restart needed).
#
#   class MyMailer < ApplicationMailer
#     include SmtpDeliverable
#     ...
#   end
#
# The concern registers an after_action that overwrites the delivery method
# with settings read from ThecoreSettings (ns: :smtp). If smtp.address is
# blank the mailer falls back to whatever delivery_method is configured in
# the Rails environment (e.g. :test or :letter_opener in development).
module SmtpDeliverable
  extend ActiveSupport::Concern

  included do
    after_action :configure_smtp_delivery
  end

  private

  def configure_smtp_delivery
    opts = ThecoreBackendCommons::SmtpConfig.delivery_options
    message.delivery_method(:smtp, opts) if opts[:address].present?
  end

  def smtp_setting(key)
    ThecoreBackendCommons::SmtpConfig.setting(key)
  end
end
