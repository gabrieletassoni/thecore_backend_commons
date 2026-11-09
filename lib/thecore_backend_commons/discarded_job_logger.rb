module ThecoreBackendCommons
  # Generic Sidekiq death handler, registered by config/initializers/sidekiq.rb: with retries off
  # Sidekiq drops a failed job without keeping it anywhere, so this writes one line to the Rails log
  # per failure. Only the job's identity goes in: class (or Mailer#action for a mail job), queue, jid
  # and the error, never the arguments, which can be huge (a PDF email carries the whole PDF) or
  # sensitive. Apps add their own handlers next to this one (`config.death_handlers << MyHandler`
  # inside `Sidekiq.configure_server`), e.g. to record failures in their own integration log.
  module DiscardedJobLogger
    MAX_MESSAGE_LENGTH = 500

    def self.call(job, exception)
      error = "#{exception.class}: #{exception.message}".truncate(MAX_MESSAGE_LENGTH)
      Rails.logger.error(
        "Background job #{name_of(job)} failed and was discarded (no retry left): " \
        "queue=#{job["queue"]} jid=#{job["jid"]} error=#{error}"
      )
    rescue StandardError => e
      Rails.logger.error("DiscardedJobLogger could not record a failed job: #{e.class}: #{e.message}")
    end

    def self.name_of(job)
      wrapped = (job["wrapped"] || job["class"]).to_s
      first = Array(job["args"]).first
      arguments = first.is_a?(Hash) ? Array(first["arguments"]) : []
      return wrapped unless wrapped == "ActionMailer::MailDeliveryJob" && arguments.size >= 2

      "#{arguments[0]}##{arguments[1]}"
    end

    private_class_method :name_of
  end
end
