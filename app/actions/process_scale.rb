module VCAP::CloudController
  class ProcessScale
    class InvalidProcess < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
    end

    def scale(process, message)
      process.db.transaction do
        process.lock!

        process.instances = message.instances if message.requested?(:instances)
        process.memory = message.memory_in_mb if message.requested?(:memory_in_mb)
        process.disk_quota = message.disk_in_mb if message.requested?(:disk_in_mb)

        process.save

        Repositories::Runtime::AppEventRepository.new.record_app_update(
          process,
          process.space,
          @user.guid,
          @user_email,
          message.audit_hash
        )
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end
  end
end
