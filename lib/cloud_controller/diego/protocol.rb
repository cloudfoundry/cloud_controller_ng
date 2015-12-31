require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/staging_request'

module VCAP::CloudController
  module Diego
    class Protocol
      def initialize(lifecycle_protocol, egress_rules)
        @lifecycle_protocol = lifecycle_protocol
        @egress_rules       = egress_rules
      end

      def stage_app_request(app, config)
        env = Environment.new(app, EnvironmentVariableGroup.staging.environment_json).as_json
        logger.debug2("staging environment: #{env.map { |e| e['name'] }}")

        lifecycle_type, lifecycle_data = @lifecycle_protocol.lifecycle_data(app)

        staging_request                     = StagingRequest.new
        staging_request.app_id              = app.guid
        staging_request.log_guid            = app.guid
        staging_request.environment         = env
        staging_request.memory_mb           = [app.memory, config[:staging][:minimum_staging_memory_mb]].max
        staging_request.disk_mb             = [app.disk_quota, config[:staging][:minimum_staging_disk_mb]].max
        staging_request.file_descriptors    = [app.file_descriptors, config[:staging][:minimum_staging_file_descriptor_limit]].max
        staging_request.egress_rules        = @egress_rules.staging
        staging_request.timeout             = config[:staging][:timeout_in_seconds]
        staging_request.lifecycle           = lifecycle_type
        staging_request.lifecycle_data      = lifecycle_data
        staging_request.completion_callback = completion_callback(app, config)

        staging_request.message
      end

      def desire_app_request(app, default_health_check_timeout)
        desire_app_message(app, default_health_check_timeout).to_json
      end

      def desire_app_message(app, default_health_check_timeout)
        env = Environment.new(app, EnvironmentVariableGroup.running.environment_json).as_json
        logger.debug2("running environment: #{env.map { |e| e['name'] }}")
        log_guid = app.is_v3? ? app.app.guid : app.guid

        {
          'process_guid'                    => ProcessGuid.from_app(app),
          'memory_mb'                       => app.memory,
          'disk_mb'                         => app.disk_quota,
          'file_descriptors'                => app.file_descriptors,
          'stack'                           => app.stack.name,
          'execution_metadata'              => app.execution_metadata,
          'environment'                     => env,
          'num_instances'                   => app.desired_instances,
          'routes'                          => app.uris,
          'routing_info'                    => app.routing_info,
          'log_guid'                        => log_guid,
          'health_check_type'               => app.health_check_type,
          'health_check_timeout_in_seconds' => app.health_check_timeout || default_health_check_timeout,
          'egress_rules'                    => @egress_rules.running(app),
          'etag'                            => app.updated_at.to_f.to_s,
          'allow_ssh'                       => app.enable_ssh,
          'ports'                           => app.ports
        }.merge(@lifecycle_protocol.desired_app_message(app))
      end

      private

      def completion_callback(app, config)
        auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
        host_port = "#{config[:internal_service_hostname]}:#{config[:external_port]}"
        path      = "/internal/staging/#{StagingGuid.from_app(app)}/completed"
        "http://#{auth}@#{host_port}#{path}"
      end

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
