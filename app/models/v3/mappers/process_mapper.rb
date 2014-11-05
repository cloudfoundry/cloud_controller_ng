module VCAP::CloudController
  class ProcessMapper

    def self.map_model_to_domain(model)
      AppProcess.new({
        guid:                 model.values[:guid],
        name:                 model.values[:name],
        space_guid:           model.space.guid,
        stack_guid:           model.stack.guid,
        disk_quota:           model.values[:disk_quota],
        memory:               model.values[:memory],
        instances:            model.values[:instances],
        state:                model.values[:state],
        command:              get_command_from_model(model),
        buildpack:            model.values[:buildpack],
        health_check_timeout: model.values[:health_check_timeout],
        docker_image:         model.values[:docker_image],
        environment_json:     model.environment_json
      })
    end

    private

    def self.get_command_from_model(model)
      metadata = MultiJson.load(model.values[:metadata])
      return nil unless metadata
      return metadata['command']
    end

  end
end
