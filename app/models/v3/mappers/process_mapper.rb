module VCAP::CloudController
  class ProcessMapper
    def self.map_model_to_domain(model)
      AppProcess.new({
        'guid'                 => model.values[:guid],
        'name'                 => model.values[:name],
        'space_guid'           => model.space && model.space.guid,
        'stack_guid'           => model.stack && model.stack.guid,
        'app_guid'             => model.values[:app_guid],
        'disk_quota'           => model.values[:disk_quota],
        'memory'               => model.values[:memory],
        'instances'            => model.values[:instances],
        'state'                => model.values[:state],
        'command'              => model.command,
        'buildpack'            => model.values[:buildpack],
        'health_check_timeout' => model.values[:health_check_timeout],
        'docker_image'         => model.values[:docker_image],
        'environment_json'     => model.environment_json,
        'created_at'           => model.created_at,
        'updated_at'           => model.updated_at,
        'type'                 => model.type
      })
    end

    def self.map_domain_to_new_model(domain)
      app = App.new

      attrs = get_attrs(domain, app)
      attrs.reject! { |_, v| v.nil? }

      map(attrs, domain, app)
    end

    def self.map_domain_to_existing_model(domain, app)
      return nil if app.nil?

      attrs = get_attrs(domain, app)
      map(attrs, domain, app)
    end

    def self.get_attrs(domain, app)
      attrs = {}
      attrs[:guid]                 = domain.guid
      attrs[:name]                 = domain.name
      attrs[:disk_quota]           = domain.disk_quota
      attrs[:memory]               = domain.memory
      attrs[:instances]            = domain.instances
      attrs[:state]                = domain.state
      attrs[:buildpack]            = domain.buildpack
      attrs[:health_check_timeout] = domain.health_check_timeout
      attrs[:space_guid]           = domain.space_guid if domain.space_guid
      attrs[:stack_guid]           = domain.stack_guid if domain.stack_guid && domain.stack_guid != app.stack_guid
      attrs[:app_guid]             = domain.app_guid
      attrs[:environment_json]     = domain.environment_json
      attrs[:docker_image]         = domain.docker_image if domain.docker_image
      attrs[:type]                 = domain.type
      attrs[:created_at]           = domain.created_at
      attrs[:updated_at]           = domain.updated_at
      attrs[:metadata]             = {}
      attrs
    end

    def self.map(attrs, domain, app)
      app.set(attrs)
      app.command = domain.command
      app
    end
  end
end
