require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/protocol/open_process_ports'
require 'cloud_controller/diego/protocol/app_volume_mounts'
require 'cloud_controller/diego/protocol/routing_info'
require 'cloud_controller/diego/protocol/container_network_info'
require 'cloud_controller/diego/lifecycle_protocol'

module VCAP::CloudController
  module Diego
    class Protocol
      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      def stage_package_request(config, staging_details)
        env = VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(staging_details.environment_variables)
        logger.debug2("staging environment: #{env.map { |e| e['name'] }}")

        lifecycle_type = staging_details.lifecycle.type
        lifecycle_data = LifecycleProtocol.protocol_for_type(lifecycle_type).lifecycle_data(staging_details)

        staging_request                     = StagingRequest.new
        staging_request.app_id              = staging_details.staging_guid
        staging_request.log_guid            = staging_details.package.app_guid
        staging_request.environment         = env
        staging_request.memory_mb           = staging_details.staging_memory_in_mb
        staging_request.disk_mb             = staging_details.staging_disk_in_mb
        staging_request.file_descriptors    = config.get(:staging, :minimum_staging_file_descriptor_limit)
        staging_request.egress_rules        = @egress_rules.staging(app_guid: staging_details.package.app_guid)
        staging_request.timeout             = config.get(:staging, :timeout_in_seconds)
        staging_request.lifecycle           = lifecycle_type
        staging_request.lifecycle_data      = lifecycle_data
        staging_request.completion_callback = staging_completion_callback(staging_details, config)
        staging_request.isolation_segment   = staging_details.isolation_segment if staging_details.isolation_segment

        staging_request.message
      end

      def desire_app_request(process, default_health_check_timeout)
        desire_app_message(process, default_health_check_timeout).to_json
      end

      def desire_app_message(process, default_health_check_timeout)
        env = Environment.new(process, EnvironmentVariableGroup.running.environment_json).as_json
        logger.debug2("running environment: #{env.map { |e| e['name'] }}")

        msg = {
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
          'log_guid'                        => process.app.guid,
          'log_source'                      => "APP/PROC/#{process.type.upcase}",
          'health_check_type'               => process.health_check_type,
          'health_check_http_endpoint'      => process.health_check_http_endpoint || '',
          'health_check_timeout_in_seconds' => process.health_check_timeout || default_health_check_timeout,
          'egress_rules'                    => @egress_rules.running(process),
          'etag'                            => process.updated_at.to_f.to_s,
          'allow_ssh'                       => process.enable_ssh,
          'ports'                           => OpenProcessPorts.new(process).to_a,
          'network'                         => ContainerNetworkInfo.new(process.app).to_h,
          'volume_mounts'                   => AppVolumeMounts.new(process.app),
          'isolation_segment'               => VCAP::CloudController::IsolationSegmentSelector.for_space(process.space),
        }.merge(LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_app_message(process))

        msg
      end

      private

      def staging_completion_callback(staging_details, config)
        auth      = "#{config.get(:internal_api, :auth_user)}:#{config.get(:internal_api, :auth_password)}"
        host_port = "#{config.get(:internal_service_hostname)}:#{config.get(:external_port)}"
        path      = "/internal/v3/staging/#{staging_details.staging_guid}/build_completed?start=#{staging_details.start_after_staging}"
        "http://#{auth}@#{host_port}#{path}"
      end

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
