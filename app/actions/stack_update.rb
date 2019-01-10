module VCAP::CloudController
  class StackUpdate
    class InvalidStack < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.stack_update')
    end

    def update(stack, message)
      if message.requested?(:metadata)
        stack.db.transaction do
          LabelsUpdate.update(stack, message.labels, StackLabelModel)
          AnnotationsUpdate.update(stack, message.annotations, StackAnnotationModel)
        end
        @logger.info("Finished updating metadata on stack #{stack.guid}")
      end
      stack
    rescue Sequel::ValidationFailed => e
      raise InvalidStack.new(e.message)
    end
  end
end
