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

        process.save

        Repositories::Runtime::AppEventRepository.new.record_app_update(
          process,
          process.space,
          @user.guid,
          @user_email,
          message.as_json({ only: message.requested_keys.map(&:to_s) })
        )
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end
  end
end
