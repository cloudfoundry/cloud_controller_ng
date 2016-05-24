require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/protocol/open_process_ports'
require 'cloud_controller/diego/protocol/app_volume_mounts'
require 'cloud_controller/diego/protocol/routing_info'
require 'cloud_controller/diego/protocol/container_network_info'

module VCAP::CloudController
  module Diego
    class Protocol
      attr_reader :process

      def initialize(process)
        @process = process
        @egress_rules = Diego::EgressRules.new
      end

      def stage_app_request(config)
        env = Environment.new(process, EnvironmentVariableGroup.staging.environment_json).as_json
        logger.debug2("staging environment: #{env.map { |e| e['name'] }}")

        lifecycle_type, lifecycle_data = lifecycle_protocol.lifecycle_data(process)

        staging_request                     = StagingRequest.new
        staging_request.app_id              = process.guid
        staging_request.log_guid            = process.guid
        staging_request.environment         = env
        staging_request.memory_mb           = [process.memory, config[:staging][:minimum_staging_memory_mb]].max
        staging_request.disk_mb             = [process.disk_quota, config[:staging][:minimum_staging_disk_mb]].max
        staging_request.file_descriptors    = [process.file_descriptors, config[:staging][:minimum_staging_file_descriptor_limit]].max
        staging_request.egress_rules        = @egress_rules.staging
        staging_request.timeout             = config[:staging][:timeout_in_seconds]
        staging_request.lifecycle           = lifecycle_type
        staging_request.lifecycle_data      = lifecycle_data
        staging_request.completion_callback = completion_callback(config)

        staging_request.message
      end

      def desire_app_request(default_health_check_timeout)
        desire_app_message(default_health_check_timeout).to_json
      end

      def desire_app_message(default_health_check_timeout)
        env = Environment.new(process, EnvironmentVariableGroup.running.environment_json).as_json
        logger.debug2("running environment: #{env.map { |e| e['name'] }}")
        log_guid = process.is_v3? ? process.app.guid : process.guid
        log_source = process.is_v3? ? "APP/PROC/#{process.type.upcase}" : 'APP'

        {
          'process_guid'                    => ProcessGuid.from_process(process),
          'memory_mb'                       => process.memory,
          'disk_mb'                         => process.disk_quota,
          'file_descriptors'                => process.file_descriptors,
          'stack'                           => process.stack.name,
          'execution_metadata'              => process.execution_metadata,
          'environment'                     => env,
          'num_instances'                   => process.desired_instances,
          'routes'                          => process.uris,
          'routing_info'                    => RoutingInfo.new(process).routing_info,
          'log_guid'                        => log_guid,
          'log_source'                      => log_source,
          'health_check_type'               => process.health_check_type,
          'health_check_timeout_in_seconds' => process.health_check_timeout || default_health_check_timeout,
          'egress_rules'                    => @egress_rules.running(process),
          'etag'                            => process.updated_at.to_f.to_s,
          'allow_ssh'                       => process.enable_ssh,
          'ports'                           => OpenProcessPorts.new(process).to_a,
          'network'                         => ContainerNetworkInfo.new(process).to_h,
          'volume_mounts'                   => AppVolumeMounts.new(process)
        }.merge(lifecycle_protocol.desired_app_message(process))
      end

      def lifecycle_protocol
        if @process.docker?
          Diego::Docker::LifecycleProtocol.new
        else
          Diego::Buildpack::LifecycleProtocol.new(::CloudController::DependencyLocator.instance.blobstore_url_generator)
        end
      end

      private

      def completion_callback(config)
        auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
        host_port = "#{config[:internal_service_hostname]}:#{config[:external_port]}"
        path      = "/internal/staging/#{StagingGuid.from_process(process)}/completed"
        "http://#{auth}@#{host_port}#{path}"
      end

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
