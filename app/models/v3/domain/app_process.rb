module VCAP::CloudController
  class AppProcess
    attr_reader :guid, :app_guid, :space_guid, :stack_guid, :disk_quota,
      :memory, :instances, :state, :command, :buildpack, :health_check_timeout,
      :docker_image, :environment_json, :name, :type, :updated_at, :created_at

    def initialize(opts)
      opts.symbolize_keys!
      @buildpack            = opts[:buildpack]
      @command              = opts[:command]
      @disk_quota           = opts[:disk_quota]
      @docker_image         = opts[:docker_image]
      @environment_json     = opts[:environment_json]
      @guid                 = opts[:guid]
      @health_check_timeout = opts[:health_check_timeout]
      @instances            = opts[:instances]
      @memory               = opts[:memory]
      @app_guid             = opts[:app_guid]
      @space_guid           = opts[:space_guid]
      @stack_guid           = opts[:stack_guid]
      @state                = opts[:state]
      @type                 = opts[:type] || 'web'
      @name                 = opts[:name] || "v3-proc-#{@type}-#{@guid}"
      @created_at           = opts[:created_at]
      @updated_at           = opts[:updated_at]
    end

    def with_changes(changes)
      AppProcess.new({
        buildpack:              self.buildpack,
        command:                self.command,
        disk_quota:             self.disk_quota,
        docker_image:           self.docker_image,
        environment_json:       self.environment_json,
        guid:                   self.guid,
        health_check_timeout:   self.health_check_timeout,
        instances:              self.instances,
        memory:                 self.memory,
        app_guid:               self.app_guid,
        space_guid:             self.space_guid,
        stack_guid:             self.stack_guid,
        state:                  self.state,
        type:                   self.type,
        name:                   self.name,
        created_at:             self.created_at,
        updated_at:             self.updated_at,
      }.merge(changes.symbolize_keys))
    end
  end
end
