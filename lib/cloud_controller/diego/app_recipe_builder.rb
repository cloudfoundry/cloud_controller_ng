require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/docker/desired_lrp_builder'
require 'cloud_controller/diego/ssh_key'

module VCAP::CloudController
  module Diego
    class AppRecipeBuilder
      include ::Diego::ActionBuilder

      def initialize(config:, process:, app_request:, ssh_key: SSHKey.new)
        @config      = config
        @process     = process
        @app_request = app_request
        @ssh_key     = ssh_key
      end

      def build_app_lrp
        desired_lrp_builder = LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_lrp_builder(config, app_request)

        ports  = desired_lrp_builder.ports
        routes = generate_routes(app_request['routing_info'])

        if allow_ssh?
          ports << DEFAULT_SSH_PORT

          routes << ::Diego::Bbs::Models::Proto_routes::RoutesEntry.new(
            key:   SSH_ROUTES_KEY,
            value: MultiJson.dump({
              container_port:   DEFAULT_SSH_PORT,
              private_key:      ssh_key.private_key,
              host_fingerprint: ssh_key.fingerprint
            })
          )
        end

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
          action:                           generate_run_action(desired_lrp_builder),
          monitor:                          generate_monitor_action(desired_lrp_builder),
          root_fs:                          desired_lrp_builder.root_fs,
          setup:                            desired_lrp_builder.setup,
          domain:                           APP_LRP_DOMAIN,
          volume_mounts:                    generate_volume_mounts,
          PlacementTags:                    [app_request['isolation_segment']],
          routes:                           ::Diego::Bbs::Models::Proto_routes.new(routes: routes)
        )
      end

      def build_app_lrp_update(existing_lrp)
        routes = generate_routes(app_request['routing_info'])

        existing_routes = ::Diego::Bbs::Models::Proto_routes.decode(existing_lrp.routes)
        ssh_route       = existing_routes.routes.find { |r| r.key == SSH_ROUTES_KEY }
        routes << ssh_route

        ::Diego::Bbs::Models::DesiredLRPUpdate.new(
          instances:  process.instances,
          annotation: process.updated_at.to_f.to_s,
          routes:     ::Diego::Bbs::Models::Proto_routes.new(routes: routes)
        )
      end

      private

      attr_reader :config, :process, :app_request, :ssh_key

      def generate_routes(info)
        http_routes = (info['http_routes'] || []).map do |i|
          {
            hostnames:         [i['hostname']],
            port:              i['port'],
            route_service_url: i['route_service_url']
          }
        end

        [
          ::Diego::Bbs::Models::Proto_routes::RoutesEntry.new(
            key:   CF_ROUTES_KEY,
            value: MultiJson.dump(http_routes)
          ),
          ::Diego::Bbs::Models::Proto_routes::RoutesEntry.new(
            key:   TCP_ROUTES_KEY,
            value: MultiJson.dump((info['tcp_routes'] || []))
          )
        ]
      end

      def allow_ssh?
        app_request['allow_ssh']
      end

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

      def generate_app_action(user, environment_variables)
        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/launcher',
                 args:            [
                   'app',
                   app_request['start_command'] || '',
                   app_request['execution_metadata'],
                 ],
                 env:             environment_variables,
                 log_source:      app_request['log_source'] || APP_LOG_SOURCE,
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
        ))
      end

      def generate_ssh_action(user, environment_variables)
        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/diego-sshd',
                 args:            [
                   "-address=#{sprintf('0.0.0.0:%d', DEFAULT_SSH_PORT)}",
                   "-hostKey=#{ssh_key.private_key}",
                   "-authorizedKey=#{ssh_key.authorized_key}",
                   '-inheritDaemonEnv',
                   '-logLevel=fatal',
                 ],
                 env:             environment_variables,
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
        ))
      end

      def generate_environment_variables(lrp_builder)
        desired_ports         = lrp_builder.ports
        environment_variables = []

        app_request['environment'].each do |i|
          environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
        end
        environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: desired_ports.first.to_s)
        environment_variables
      end

      def generate_run_action(lrp_builder)
        environment_variables = generate_environment_variables(lrp_builder)

        actions = []
        actions << generate_app_action(lrp_builder.action_user, environment_variables)
        actions << generate_ssh_action(lrp_builder.action_user, environment_variables) if allow_ssh?
        codependent(actions)
      end

      def generate_monitor_action(lrp_builder)
        return if app_request['health_check_type'] == 'none'

        desired_ports = lrp_builder.ports
        actions       = []
        desired_ports.each_with_index do |port, index|
          actions << build_action(lrp_builder, port, index)
        end

        action(timeout(parallel(actions), timeout_ms: 1000 * 30.seconds))
      end

      def build_action(lrp_builder, port, index)
        extra_args = []
        if app_request['health_check_type'] == 'http' && index == 0
          extra_args << "-uri=#{app_request['health_check_http_endpoint']}"
        end

        ::Diego::Bbs::Models::RunAction.new(
          user:                lrp_builder.action_user,
          path:                '/tmp/lifecycle/healthcheck',
          args:                ["-port=#{port}"].concat(extra_args),
          resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
          log_source:          HEALTH_LOG_SOURCE,
          suppress_log_output: true,
        )
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
        file_descriptors.zero? ? DEFAULT_FILE_DESCRIPTOR_LIMIT : file_descriptors
      end
    end
  end
end
