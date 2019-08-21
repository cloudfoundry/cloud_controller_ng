module VCAP::CloudController
  class UserCreate
    class Error < StandardError
    end

    def create(message:)
      uaa_client = CloudController::DependencyLocator.instance.uaa_client
      user = User.create(guid: message.guid)

      uaa_user = uaa_client.users_for_ids([user.guid])[user.guid]
      user.username = uaa_user['username'] if uaa_user
      user.origin = uaa_user['origin'] if uaa_user
      user
    rescue Sequel::ValidationFailed => e
      validation_error!(message, e)
    end

    private

    def validation_error!(message, error)
      if error.errors.on(:guid)&.any? { |e| [:unique].include?(e) }
        error!("User with guid '#{message.guid}' already exists.")
      end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
