module VCAP::CloudController
  class JobPriorityOverwriter
    def initialize(config)
      @overwritten_job_priorities = config.get(:jobs, :priorities)
    end

    def get(job_display_name)
      if is_overwritten(job_display_name)
        @overwritten_job_priorities[job_display_name.to_sym]
      end
    end

    private

    def is_overwritten(job_display_name)
      return false if @overwritten_job_priorities.nil? || job_display_name.nil?

      @overwritten_job_priorities.key?(job_display_name.to_sym)
    end

    attr_reader :config
  end
end
