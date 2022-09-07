module VCAP::CloudController
  class ProcessScale
    class InvalidProcess < StandardError; end
    class SidecarMemoryLessThanProcessMemory < StandardError; end

    def initialize(user_audit_info, process, message, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @process = process
      @message = message
      @manifest_triggered = manifest_triggered
    end

    def scale
      if @process.web? && @process.app.deploying?
        raise InvalidProcess.new('Cannot scale this process while a deployment is in flight.')
      end

      @process.db.transaction do
        @process.app.lock!
        @process.lock!

        @process.instances = @message.instances if @message.requested?(:instances)
        @process.memory = @message.memory_in_mb if @message.requested?(:memory_in_mb)
        @process.disk_quota = @message.disk_in_mb if @message.requested?(:disk_in_mb)
        if @message.requested?(:log_rate_limit_in_bytes_per_second) && !@message.log_rate_limit_in_bytes_per_second.nil?
          @process.log_rate_limit = @message.log_rate_limit_in_bytes_per_second
        end
        @process.save

        record_audit_event
      end
    rescue Sequel::ValidationFailed => e
      if @process.errors.on(:memory)&.include?(:process_memory_insufficient_for_sidecars)
        raise SidecarMemoryLessThanProcessMemory.new('The requested memory allocation is not large enough to run all of your sidecar processes')
      end

      raise InvalidProcess.new(e.message)
    end

    private

    def record_audit_event
      Repositories::ProcessEventRepository.record_scale(
        @process,
        @user_audit_info,
        @message.audit_hash,
        manifest_triggered: @manifest_triggered
      )
    end
  end
end
