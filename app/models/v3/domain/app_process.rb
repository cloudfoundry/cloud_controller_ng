module VCAP::CloudController
  class AppProcess
    attr_reader :guid, :app_guid, :space_guid, :stack_guid, :disk_quota,
      :memory, :instances, :state, :command, :buildpack, :health_check_timeout,
      :docker_image, :environment_json, :name

    attr_reader :changes

    def initialize(opts, changes={})
      @guid                 = opts[:guid]
      @app_guid             = opts[:app_guid]
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

      @changes = changes
    end
  end
end
