module VCAP::CloudController
  class ProcessScale
    class InvalidProcess < StandardError; end

    def initialize(user, user_email, process, message)
      @user       = user
      @user_email = user_email
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
        @user.guid,
        @user_email,
        @message.audit_hash
      )
    end
  end
end
