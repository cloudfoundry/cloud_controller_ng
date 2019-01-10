module VCAP::CloudController
  class StackCreate
    class Error < ::StandardError
    end

    def create(message)
      stack = VCAP::CloudController::Stack.create(
        name: message.name,
        description: message.description
      )

      if message.requested?(:metadata)
        LabelsUpdate.update(stack, message.labels, StackLabelModel)
        AnnotationsUpdate.update(stack, message.annotations, StackAnnotationModel)
      end

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
