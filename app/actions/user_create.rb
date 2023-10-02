module VCAP::CloudController
  class UserCreate
    class Error < StandardError
    end

    def create(message:)
      user = User.create(guid: message.guid)
      User.db.transaction do
        MetadataUpdate.update(user, message)
      end
      user
    rescue Sequel::ValidationFailed => e
      validation_error!(message, e)
    end

    private

    def validation_error!(message, error)
      error!("User with guid '#{message.guid}' already exists.") if error.errors.on(:guid)&.any? { |e| [:unique].include?(e) }

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
