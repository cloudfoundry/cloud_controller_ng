module VCAP::CloudController
  class TaskUpdate
    class InvalidTask < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.task_update')
    end

    def update(task, message)
      task.db.transaction do
        MetadataUpdate.update(task, message)
      end
      @logger.info("Finished updating metadata on task #{task.guid}")
      task
    rescue Sequel::ValidationFailed => e
      raise InvalidTask.new(e.message)
    end
  end
end
