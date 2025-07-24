module VCAP::CloudController
  class StackCreate
    class Error < ::StandardError
    end

    def create(message)
      stack = VCAP::CloudController::Stack.create(
        name: message.name,
        description: message.description,
        deprecated_at: message.deprecated_at,
        locked_at: message.locked_at,
        disabled_at: message.disabled_at
      )

      MetadataUpdate.update(stack, message)

      stack
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    def validation_error!(error)
      error!('Name must be unique') if error.errors.on(:name)&.include?(:unique)
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
