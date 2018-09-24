module VCAP::CloudController
  class CopilotRunnerDelegator < Delegator
    def initialize(runner, process)
      @runner = runner
      @process = process
    end

    def __getobj__
      @runner
    end

    def __setobj__(obj)
      @runner = obj
    end

    def start
      @runner.start
      Copilot::Adapter.upsert_capi_diego_process_association(@process)
    end

    def stop
      @runner.stop
      Copilot::Adapter.delete_capi_diego_process_association(@process)
    end
  end
end
