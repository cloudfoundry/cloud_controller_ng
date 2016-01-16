module VCAP::CloudController
  class TaskCreate
    class InvalidTask < StandardError; end

    def create(app, message)
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
  end
end
