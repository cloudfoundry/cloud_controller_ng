module VCAP::CloudController
  class ProcessTerminate
    class InstanceNotFound < StandardError; end

    def initialize(user_audit_info, process, index)
      @user_audit_info = user_audit_info
      @process    = process
      @index      = index
    end

    def terminate
      raise InstanceNotFound unless @index < @process.instances && @index >= 0
      index_stopper.stop_index(@process, @index)
      record_audit_events
    end

    private

    def record_audit_events
      Repositories::ProcessEventRepository.record_terminate(
        @process,
        @user_audit_info,
        @index
      )
    end

    def index_stopper
      CloudController::DependencyLocator.instance.index_stopper
    end
  end
end
