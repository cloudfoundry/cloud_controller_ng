module VCAP::CloudController
  class ProcessTerminate
    class InstanceNotFound < StandardError; end

    def initialize(user_guid, user_email, process, index)
      @user_guid  = user_guid
      @user_email = user_email
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
        @user_guid,
        @user_email,
        @index
      )
    end

    def index_stopper
      CloudController::DependencyLocator.instance.index_stopper
    end
  end
end
