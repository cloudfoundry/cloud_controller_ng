module VCAP::CloudController
  class TaskCreate
    class InvalidTask < StandardError; end
    class TaskCreateError < StandardError; end
    class NoAssignedDroplet < TaskCreateError; end

    def create(app, message)
      no_assigned_droplet! unless app.droplet
      TaskModel.create(
        name:    message.name,
        state:   TaskModel::RUNNING_STATE,
        droplet: app.droplet,
        command: message.command,
        app:     app
      )
    rescue Sequel::ValidationFailed => e
      raise InvalidTask.new(e.message)
    end

    private

    def no_assigned_droplet!
      raise NoAssignedDroplet.new('Task must have a droplet. Specify droplet or assign current droplet to app.')
    end
  end
end
