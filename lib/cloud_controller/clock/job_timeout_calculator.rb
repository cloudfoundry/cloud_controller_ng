module VCAP::CloudController
  class JobTimeoutCalculator
    JOBS_WITH_TIMEOUTS = %i(app_usage_events_cleanup blobstore_delete diego_sync).freeze

    def initialize(config)
      @config = config
    end

    def calculate(job_name)
      specified_timeout(job_name) || config.get(:jobs, :global, :timeout_in_seconds)
    end

    private

    def specified_timeout(job_name)
      JOBS_WITH_TIMEOUTS.include?(job_name) && config.get(:jobs, job_name.to_sym, :timeout_in_seconds)
    end

    attr_reader :config
  end
end
