module VCAP::CloudController
  class UserCreate
    class Error < StandardError
    end

    def create(message:)
      user = User.create(guid: message.guid)
      UsernamePopulator.new(CloudController::DependencyLocator.instance.uaa_client).transform(user).first
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
