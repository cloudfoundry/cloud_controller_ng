module VCAP::CloudController
  class StartAppMessage < Hash
    def initialize(app, index, config, blobstore_url_generator)
      super()

      self[:droplet]        = app.guid
      self[:name]           = app.name
      self[:uris]           = app.uris
      self[:prod]           = app.production
      self[:sha1]           = app.droplet_hash
      self[:executableFile] = "deprecated"
      self[:executableUri]  = blobstore_url_generator.droplet_download_url(app)
      self[:version]        = app.version

      self[:services] = app.service_bindings.map do |sb|
        ServiceBindingPresenter.new(sb).to_hash
      end

      self[:limits] = {
        mem:  app.memory,
        disk: app.disk_quota,
        fds:  app.file_descriptors
      }

      self[:cc_partition]         = config[:cc_partition]
      self[:env]                  = (app.environment_json || {}).map { |k, v| "#{k}=#{v}" }
      self[:console]              = app.console
      self[:debug]                = app.debug
      self[:start_command]        = app.command
      self[:health_check_timeout] = app.health_check_timeout
      self[:vcap_application]     = app.vcap_application
      self[:index]                = index
      self[:egress_network_rules] = EgressNetworkRulesPresenter.new(app.space.app_security_groups).to_array
    end

    def has_app_package?
      return !self[:executableUri].nil?
    end
  end
end
