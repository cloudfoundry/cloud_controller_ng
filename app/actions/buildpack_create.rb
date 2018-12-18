module VCAP::CloudController
  class BuildpackCreate
    class Error < ::StandardError
    end

    def create(message)
      Buildpack.create(
        name: message.name,
        stack: message.stack,
        position: message.position,
        enabled: message.enabled,
        locked: message.locked,
      )
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end

    def validation_error!(error, create_message)
      if error.errors.on(:stack)&.include?(:buildpack_stack_does_not_exist)
        error!(%{Stack "#{create_message.stack}" does not exist})
      end
      if error.errors.on([:name, :stack])&.include?(:unique)
        error!(%{The buildpack name "#{create_message.name}" with the stack "#{create_message.stack}" is already in use})
      end

      if error.errors.on(:stack)&.include?(:unique)
        error!(%{The buildpack name "#{create_message.name}" with an unassigned stack is already in use})
      end

      error!(error.message)
    end

    def error!(error_message)
      raise Error.new(error_message)
    end
  end
end
