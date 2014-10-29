module VCAP::CloudController
  class ProcessRepository
    class InvalidProcess < StandardError; end
    class ProcessNotFound < StandardError; end

    def new(opts)
      AppProcess.new(opts)
    end

    def persist!(desired_process)
      attributes = {
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
      }.reject{ |_, v| v.nil? }

      process_model = if desired_process.guid
                        App.first!(guid: desired_process.guid).update(attributes)
                      else
                        App.create(attributes)
                      end

      process_from_model(process_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    rescue Sequel::NoMatchingRow => e
      raise ProcessNotFound.new(e.message)
    end

    def find_by_guid(guid)
      process_model = App.find(guid: guid)
      return if process_model.nil?
      process_from_model(process_model)
    end
    
    def update(process, changes)
      attributes = {
        guid: process.guid,
        name: process.name,
        space_guid: process.space_guid,
        stack_guid: process.stack_guid,
        disk_quota: process.disk_quota,
        memory: process.memory,
        instances: process.instances,
        state: process.state,
        command: process.command,
        buildpack: process.buildpack,
        health_check_timeout: process.health_check_timeout,
        docker_image: process.docker_image,
        environment_json: process.environment_json
      }.merge(changes)
      AppProcess.new(attributes)
    end

    def delete(process)
      process_model = App.find(guid: process.guid)
      process_model.destroy if process_model
    end

    private

    def process_from_model(model)
      AppProcess.new({
        guid: model.values[:guid],
        name: model.values[:name],
        space_guid: model.space.guid,
        stack_guid: model.stack.guid,
        disk_quota: model.values[:disk_quota],
        memory: model.values[:memory],
        instances: model.values[:instances],
        state: model.values[:state],
        command: model.values[:command],
        buildpack: model.values[:buildpack],
        health_check_timeout: model.values[:health_check_timeout],
        docker_image: model.values[:docker_image],
        environment_json: model.environment_json
      })
    end
  end
end
