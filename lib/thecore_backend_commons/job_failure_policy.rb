module ThecoreBackendCommons
  # What happens to a failed background job, app-wide, read from the container's environment by
  # config/initializers/sidekiq.rb (docs/adr/0002-no-job-retries-failures-logged.md):
  #
  # - THECORE_JOB_RETRIES: how many times Sidekiq retries a failed job. Unset or blank = 0, i.e.
  #   `retry: false` (not `retry: 0`, which would still send the job to the Dead Set).
  # - THECORE_FAILED_JOBS_KEPT: how many failed jobs sidekiq-failures keeps in the Redis `failed`
  #   set, payload and arguments included (Sidekiq.failures_max_count). Unset or blank = 1, the
  #   latest, still shown in the Failures tab.
  #
  # Any other value refuses to boot: a typo must never silently re-enable retries or keep every
  # failed payload. A job class still overrides the retry count with `sidekiq_options retry: N`.
  # Required, not autoloaded: see the ADR.
  module JobFailurePolicy
    RETRIES_VARIABLE = "THECORE_JOB_RETRIES".freeze
    KEPT_VARIABLE = "THECORE_FAILED_JOBS_KEPT".freeze
    DEFAULT_RETRIES = 0
    DEFAULT_KEPT = 1

    class InvalidValue < StandardError; end

    # Sets Sidekiq's app-wide default retry option and the sidekiq-failures cap.
    def self.apply!
      Sidekiq.default_job_options = Sidekiq.default_job_options.merge("retry" => sidekiq_retry_option)
      Sidekiq.failures_max_count = failed_jobs_kept
    end

    # The value for Sidekiq's `retry` option: false for no retries, else the count.
    def self.sidekiq_retry_option
      retries.zero? ? false : retries
    end

    def self.retries
      whole_number_from_env(RETRIES_VARIABLE, default: DEFAULT_RETRIES, minimum: 0, expected: "a whole number >= 0")
    end

    def self.failed_jobs_kept
      whole_number_from_env(KEPT_VARIABLE, default: DEFAULT_KEPT, minimum: 1, expected: "a whole number >= 1")
    end

    # The whole number in the environment variable, default when unset or blank; raises InvalidValue
    # on anything else or below minimum.
    def self.whole_number_from_env(variable, default:, minimum:, expected:)
      raw = ENV.fetch(variable, nil)
      return default if raw.nil? || raw.strip.empty?

      value = raw.strip
      return value.to_i if value.match?(/\A\d+\z/) && value.to_i >= minimum

      raise InvalidValue, "#{variable}=#{raw.inspect} is not valid: use #{expected}, or leave it unset (default #{default})"
    end
    private_class_method :whole_number_from_env
  end
end
