module VCAP::CloudController
  class StackCreate
    class Error < ::StandardError
    end

    def create(message)
      VCAP::CloudController::Stack.create(
        name: message.name,
        description: message.description
      )
    rescue Sequel::ValidationFailed => e
      error!(e)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
