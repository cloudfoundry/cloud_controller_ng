module VCAP::CloudController
  class ProcessHandler
    class InvalidProcess < StandardError; end

    def new(opts)
      AppProcess.new(opts)
    end

    def persist!(desired_process)
      process_model = ProcessModel.create({
        guid: desired_process.guid,
        name: desired_process.name,
        space_guid: desired_process.space_guid,
        stack_guid: desired_process.stack_guid,
        disk_quota: desired_process.disk_quota,
        memory: desired_process.memory,
        instances: desired_process.instances,
        state: desired_process.state,
        command: desired_process.command,
        buildpack: desired_process.buildpack,
        health_check_timeout: desired_process.health_check_timeout,
        docker_image: desired_process.docker_image,
        environment_json: desired_process.environment_json
      }.reject{ |_, v| v.nil? })
      process_from_model(process_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end

    def find_by_guid(guid)
      process_model = ProcessModel.find(guid: guid)
      return if process_model.nil?
      process_from_model(process_model)
    end

    def delete(process)
      process_model = ProcessModel.find(guid: process.guid)
      process_model.destroy if process_model
    end

    private

    def process_from_model(model)
      AppProcess.new({
        guid: model.guid,
        name: model.name,
        space_guid: model.space_guid,
        stack_guid: model.stack_guid,
        disk_quota: model.disk_quota,
        memory: model.memory,
        instances: model.instances,
        state: model.state,
        command: model.command,
        buildpack: model.buildpack,
        health_check_timeout: model.health_check_timeout,
        docker_image: model.docker_image,
        environment_json: model.environment_json
      })
    end
  end
end
