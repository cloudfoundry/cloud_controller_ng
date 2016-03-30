module VCAP::CloudController
  class ProcessUpdate
    class InvalidProcess < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
    end

    def update(process, message)
      process.db.transaction do
        process.lock!

        process.command              = message.command if message.requested?(:command)
        process.health_check_type    = message.health_check_type if message.requested?(:health_check_type)
        process.health_check_timeout = message.health_check_timeout if message.requested?(:health_check_timeout)

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
