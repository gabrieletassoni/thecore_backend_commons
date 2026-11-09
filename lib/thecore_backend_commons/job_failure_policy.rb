module ThecoreBackendCommons
  # What happens to a failed background job, app-wide, read from the container's environment by
  # config/initializers/sidekiq.rb (docs/adr/0002-no-job-retries-failures-logged.md):
  #
  # - THECORE_JOB_RETRIES: how many times Sidekiq retries a failed job. Unset or blank = 0, i.e.
  #   `retry: false` (not `retry: 0`, which would still send the job to the Dead Set). A Thecore
  #   app's Redis once grew to 23 GB from retried mail jobs each carrying a whole PDF.
  # - THECORE_FAILED_JOBS_KEPT: how many failed jobs sidekiq-failures keeps in the Redis `failed`
  #   set, payload and arguments included (Sidekiq.failures_max_count). Unset or blank = 1, the
  #   latest, still shown in the Failures tab.
  #
  # Any other value refuses to boot: a typo must never silently re-enable retries or keep every
  # failed payload. A job class still overrides the retry count with `sidekiq_options retry: N`.
  # A plain require from lib/thecore_backend_commons.rb, not autoloaded: autoloaded constants
  # aren't available to initializers.
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
      integer(RETRIES_VARIABLE, default: DEFAULT_RETRIES, minimum: 0, expected: "a whole number >= 0")
    end

    def self.failed_jobs_kept
      integer(KEPT_VARIABLE, default: DEFAULT_KEPT, minimum: 1, expected: "a whole number >= 1")
    end

    def self.integer(variable, default:, minimum:, expected:)
      raw = ENV.fetch(variable, nil)
      return default if raw.nil? || raw.strip.empty?

      value = raw.strip
      return value.to_i if value.match?(/\A\d+\z/) && value.to_i >= minimum

      raise InvalidValue, "#{variable}=#{raw.inspect} is not valid: use #{expected}, or leave it unset (default #{default})"
    end
    private_class_method :integer
  end
end
