module VCAP::CloudController
  class ProcessScale
    class InvalidProcess < StandardError; end

    def initialize(user_audit_info, process, message)
      @user_audit_info = user_audit_info
      @process    = process
      @message    = message
    end

    def scale
      @process.db.transaction do
        @process.app.lock!
        @process.lock!

        @process.instances = @message.instances if @message.requested?(:instances)
        @process.memory = @message.memory_in_mb if @message.requested?(:memory_in_mb)
        @process.disk_quota = @message.disk_in_mb if @message.requested?(:disk_in_mb)

        @process.save

        record_audit_event
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end

    private

    def record_audit_event
      Repositories::ProcessEventRepository.record_scale(
        @process,
        @user_audit_info,
        @message.audit_hash
      )
    end
  end
end
