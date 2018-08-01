require 'presenters/message_bus/service_binding_presenter'

module VCAP::CloudController
  module Dea
    class StartAppMessage < Hash
      def initialize(process, index, config, blobstore_url_generator)
        super()

        self[:droplet]        = process.guid
        self[:name]           = process.name
        self[:stack]          = process.stack.name
        self[:uris]           = process.uris
        self[:prod]           = process.production
        self[:sha1]           = process.droplet_hash
        self[:executableFile] = 'deprecated'
        self[:executableUri]  = blobstore_url_generator.droplet_download_url(process.current_droplet)
        self[:version]        = process.version

        self[:services] = process.service_bindings.map do |sb|
          ServiceBindingPresenter.new(sb, include_instance: true).to_hash
        end

        self[:limits] = {
            mem:  process.memory,
            disk: process.disk_quota,
            fds:  process.file_descriptors
        }

        staging_env = EnvironmentVariableGroup.running.environment_json
        app_env     = process.environment_json || {}
        env         = staging_env.merge(app_env).merge({ 'CF_PROCESS_TYPE' => process.type }).map { |k, v| "#{k}=#{v}" }
        self[:env]  = env

        self[:cc_partition]         = config[:cc_partition]
        self[:console]              = process.console
        self[:debug]                = process.debug
        self[:start_command]        = process.command
        self[:health_check_timeout] = process.health_check_timeout

        self[:vcap_application]     = VCAP::VarsBuilder.new(process).to_hash

        self[:index]                = index
        self[:egress_network_rules] = EgressNetworkRulesPresenter.new(process.space.security_groups).to_array
      end

      def has_app_package?
        !self[:executableUri].nil?
      end
    end
  end
end
