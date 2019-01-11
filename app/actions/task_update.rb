module VCAP::CloudController
  class TaskUpdate
    class InvalidTask < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.task_update')
    end

    def update(task, message)
      if message.requested?(:metadata)
        task.db.transaction do
          LabelsUpdate.update(task, message.labels, TaskLabelModel)
          AnnotationsUpdate.update(task, message.annotations, TaskAnnotationModel)
        end
        @logger.info("Finished updating metadata on task #{task.guid}")
      end
      task
    rescue Sequel::ValidationFailed => e
      raise InvalidTask.new(e.message)
    end
  end
end
