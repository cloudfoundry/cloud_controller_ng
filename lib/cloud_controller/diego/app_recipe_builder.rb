require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/docker/desired_lrp_builder'

module VCAP::CloudController
  module Diego
    class AppRecipeBuilder
      include ::Diego::ActionBuilder

      def initialize(config:, process:, app_request:)
        @config      = config
        @process     = process
        @app_request = app_request
      end

      def build_app_lrp
        desired_lrp_builder = LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_lrp_builder(config, app_request)

        ::Diego::Bbs::Models::DesiredLRP.new(
          process_guid:                     app_request['process_guid'],
          instances:                        app_request['num_instances'],
          environment_variables:            desired_lrp_builder.global_environment_variables,
          start_timeout_ms:                 app_request['health_check_timeout_in_seconds'] * 1000,
          disk_mb:                          app_request['disk_mb'],
          memory_mb:                        app_request['memory_mb'],
          privileged:                       desired_lrp_builder.privileged?,
          ports:                            desired_lrp_builder.ports,
          log_source:                       LRP_LOG_SOURCE,
          log_guid:                         app_request['log_guid'],
          metrics_guid:                     app_request['log_guid'],
          annotation:                       app_request['etag'],
          egress_rules:                     generate_egress_rules,
          cached_dependencies:              desired_lrp_builder.cached_dependencies,
          legacy_download_user:             'root',
          trusted_system_certificates_path: RUNNING_TRUSTED_SYSTEM_CERT_PATH,
          network:                          generate_network,
          cpu_weight:                       TaskCpuWeightCalculator.new(memory_in_mb: app_request['memory_mb']).calculate,
          action:                           action(
            ::Diego::Bbs::Models::CodependentAction.new(actions: generate_app_action(desired_lrp_builder))
                                            ),
          monitor:                          generate_monitor_action(desired_lrp_builder),
          root_fs:                          desired_lrp_builder.root_fs,
          setup:                            desired_lrp_builder.setup,
          domain:                           APP_LRP_DOMAIN,
          volume_mounts:                    generate_volume_mounts,
        )
      end

      def build_app_lrp_update
        ::Diego::Bbs::Models::DesiredLRPUpdate.new(
          instances:  process.instances,
          annotation: process.updated_at.to_f.to_s,
        )
      end

      private

      attr_reader :config, :process, :app_request

      def generate_volume_mounts
        app_volume_mounts   = app_request['volume_mounts'].as_json
        proto_volume_mounts = []

        app_volume_mounts.each do |volume_mount|
          proto_volume_mount = ::Diego::Bbs::Models::VolumeMount.new(
            driver:        volume_mount['device']['driver'],
            container_dir: volume_mount['container_dir'],
            mode:          volume_mount['mode']
          )

          mount_config              = volume_mount['device']['mount_config'].present? ? volume_mount['device']['mount_config'].to_json : ''
          proto_volume_mount.shared = ::Diego::Bbs::Models::SharedDevice.new(
            volume_id:    volume_mount['device']['volume_id'],
            mount_config: mount_config
          )
          proto_volume_mounts.append(proto_volume_mount)
        end

        proto_volume_mounts
      end

      def generate_app_action(lrp_builder)
        desired_ports         = lrp_builder.ports
        environment_variables = []

        app_request['environment'].each do |i|
          environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
        end
        environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: desired_ports.first.to_s)

        [
          action(
            ::Diego::Bbs::Models::RunAction.new(
              user:            lrp_builder.action_user,
              path:            '/tmp/lifecycle/launcher',
              args:            [
                'app',
                app_request['start_command'] || '',
                app_request['execution_metadata'],
              ],
              env:             environment_variables,
              log_source:      app_request['log_source'] || APP_LOG_SOURCE,
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
            )
          )
        ]
      end

      def generate_monitor_action(lrp_builder)
        return unless ['', 'port'].include?(app_request['health_check_type'])

        desired_ports = lrp_builder.ports
        actions       = []
        desired_ports.each do |port|
          actions << ::Diego::Bbs::Models::RunAction.new(
            user:                lrp_builder.action_user,
            path:                '/tmp/lifecycle/healthcheck',
            args:                ["-port=#{port}"],
            resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
            log_source:          HEALTH_LOG_SOURCE,
            suppress_log_output: true,
          )
        end

        action(timeout(parallel(actions), timeout_ms: 1000 * 30.seconds))
      end

      def generate_egress_rules
        app_request['egress_rules'].map do |rule|
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     rule['protocol'],
            destinations: rule['destinations'],
            ports:        rule['ports'],
            port_range:   rule['port_range'],
            icmp_info:    rule['icmp_info'],
            log:          rule['log'],
          )
        end
      end

      def generate_network
        network = ::Diego::Bbs::Models::Network.new(properties: [])

        app_request['network']['properties'].each do |key, value|
          network.properties << ::Diego::Bbs::Models::Network::PropertiesEntry.new(
            key:   key,
            value: value,
          )
        end

        network
      end

      def file_descriptor_limit(file_descriptors)
        file_descriptors == 0 ? DEFAULT_FILE_DESCRIPTOR_LIMIT : file_descriptors
      end
    end
  end
end
