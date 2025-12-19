module VCAP::CloudController
  class ExecutionContext
    ExecutionInfo = Struct.new(:process_type, :capi_job_name, :rake_context, keyword_init: true) do
      def initialize(process_type:, capi_job_name:, rake_context: nil)
        super
      end

      def set_process_type_env
        ENV['PROCESS_TYPE'] = process_type
      end

      def set_rake_context
        raise 'RakeConfig is not defined or rake_context argument is nil' if rake_context.nil? || !Object.const_defined?(:RakeConfig)

        RakeConfig.context = rake_context
      end
    end

    API_PUMA_MAIN = ExecutionInfo.new(process_type: 'main', capi_job_name: 'cloud_controller_ng')
    API_PUMA_WORKER = ExecutionInfo.new(process_type: 'puma_worker', capi_job_name: 'cloud_controller_ng')
    CC_WORKER = ExecutionInfo.new(process_type: 'cc-worker', capi_job_name: 'cloud_controller_worker', rake_context: :worker)
    CLOCK = ExecutionInfo.new(process_type: 'clock', capi_job_name: 'cloud_controller_clock', rake_context: :clock)
    DEPLOYMENT_UPDATER = ExecutionInfo.new(process_type: 'deployment_updater', capi_job_name: 'cc_deployment_updater', rake_context: :deployment_updater)

    ALL_EXECUTION_CONTEXTS = [API_PUMA_MAIN, API_PUMA_WORKER, CC_WORKER, CLOCK, DEPLOYMENT_UPDATER].freeze

    class << self
      def from_process_type_env
        process_type = ENV.fetch('PROCESS_TYPE', nil)
        exec_ctx = ALL_EXECUTION_CONTEXTS.find { |p| p.process_type == process_type }

        # For test environments where PROCESS_TYPE may not be set, default to API_PUMA_MAIN
        exec_ctx = API_PUMA_MAIN if exec_ctx.nil? && ENV.fetch('CC_TEST', nil) == 'true'

        exec_ctx
      end
    end
  end
end
