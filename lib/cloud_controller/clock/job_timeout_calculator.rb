module VCAP::CloudController
  class JobTimeoutCalculator
    def initialize(config)
      @config = config
    end

    def calculate(job_name)
      job_name ||= :global
      config.config_hash.dig(:jobs, job_name.to_sym, :timeout_in_seconds) || config.config_hash.dig(:jobs, :global, :timeout_in_seconds)
    end

    private

    attr_reader :config
  end
end
