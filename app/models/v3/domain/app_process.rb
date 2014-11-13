module VCAP::CloudController
  class AppProcess
    attr_reader :guid, :space_guid, :stack_guid, :disk_quota,
      :memory, :instances, :state, :command, :buildpack, :health_check_timeout,
      :docker_image, :environment_json, :name

    def initialize(opts)
      @guid                 = opts[:guid]
      @name                 = opts[:name]
      @space_guid           = opts[:space_guid]
      @stack_guid           = opts[:stack_guid]
      @disk_quota           = opts[:disk_quota]
      @memory               = opts[:memory]
      @instances            = opts[:instances]
      @state                = opts[:state]
      @command              = opts[:command]
      @buildpack            = opts[:buildpack]
      @health_check_timeout = opts[:health_check_timeout]
      @docker_image         = opts[:docker_image]
      @environment_json     = opts[:environment_json]
    end

    def with_changes(changes)
      AppProcess.new({
          guid:                 self.guid,
          name:                 self.name,
          space_guid:           self.space_guid,
          stack_guid:           self.stack_guid,
          disk_quota:           self.disk_quota,
          memory:               self.memory,
          instances:            self.instances,
          state:                self.state,
          command:              self.command,
          buildpack:            self.buildpack,
          health_check_timeout: self.health_check_timeout,
          docker_image:         self.docker_image,
          environment_json:     self.environment_json
        }.merge(changes))
    end
  end
end
