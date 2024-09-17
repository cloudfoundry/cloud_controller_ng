module VCAP::CloudController
  class JobTimeoutCalculator
    JOBS_WITH_TIMEOUTS = %i[app_usage_events_cleanup blobstore_delete diego_sync].freeze
    QUEUES_WITH_TIMEOUT = %w[cc-generic].freeze

    def initialize(config)
      @config = config
    end

    def calculate(job_name, queue_name=nil)
      job_timeout(job_name) || (queue_name && queue_timeout(queue_name)) || config.get(:jobs, :global, :timeout_in_seconds)
    end

    private

    def job_timeout(job_name)
      JOBS_WITH_TIMEOUTS.include?(job_name) && config.get(:jobs, job_name.to_sym, :timeout_in_seconds)
    end

    def queue_timeout(queue_name)
      queue_symbol = queue_name == 'cc-generic' ? :cc_generic : queue_name.to_sym
      QUEUES_WITH_TIMEOUT.include?(queue_name) && config.get(:jobs, :queues, queue_symbol, :timeout_in_seconds)
    end

    attr_reader :config
  end
end
