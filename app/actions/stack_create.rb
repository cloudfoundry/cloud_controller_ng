module VCAP::CloudController
  class StackCreate
    class Error < ::StandardError
    end

    def create(message)
      stack = VCAP::CloudController::Stack.create(
        name: message.name,
        description: message.description
      )

      MetadataUpdate.update(stack, message)

      stack
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    def validation_error!(error)
      if error.errors.on(:name)&.include?(:unique)
        error!('Name must be unique')
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
