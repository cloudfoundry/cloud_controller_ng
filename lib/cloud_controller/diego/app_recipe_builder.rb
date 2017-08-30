require 'cloud_controller/diego/protocol/app_volume_mounts'
require 'cloud_controller/diego/protocol/container_network_info'
require 'cloud_controller/diego/protocol/routing_info'
require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/docker/desired_lrp_builder'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/ssh_key'

module VCAP::CloudController
  module Diego
    class AppRecipeBuilder
      include ::Diego::ActionBuilder

      MONITORED_HEALTH_CHECK_TYPES = ['port', 'http', ''].map(&:freeze).freeze

      def initialize(config:, process:, ssh_key: SSHKey.new)
        @config  = config
        @process = process
        @ssh_key = ssh_key
      end

      def build_app_lrp
        desired_lrp_builder = LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_lrp_builder(config, process)

        ports  = desired_lrp_builder.ports
        routes = generate_routes(routing_info)

        if allow_ssh?
          ports << DEFAULT_SSH_PORT

          routes << ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
            key:   SSH_ROUTES_KEY,
            value: MultiJson.dump({
              container_port:   DEFAULT_SSH_PORT,
              private_key:      ssh_key.private_key,
              host_fingerprint: ssh_key.fingerprint
            })
          )
        end

        process_guid = ProcessGuid.from_process(process)

        ::Diego::Bbs::Models::DesiredLRP.new(
          process_guid:                     process_guid,
          instances:                        process.desired_instances,
          environment_variables:            desired_lrp_builder.global_environment_variables,
          start_timeout_ms:                 health_check_timeout_in_seconds * 1000,
          disk_mb:                          process.disk_quota,
          memory_mb:                        process.memory,
          privileged:                       desired_lrp_builder.privileged?,
          ports:                            desired_lrp_builder.ports,
          log_source:                       LRP_LOG_SOURCE,
          log_guid:                         process.app.guid,
          metrics_guid:                     process.app.guid,
          annotation:                       process.updated_at.to_f.to_s,
          egress_rules:                     generate_egress_rules,
          cached_dependencies:              desired_lrp_builder.cached_dependencies,
          legacy_download_user:             'root',
          trusted_system_certificates_path: RUNNING_TRUSTED_SYSTEM_CERT_PATH,
          network:                          generate_network,
          cpu_weight:                       TaskCpuWeightCalculator.new(memory_in_mb: process.memory).calculate,
          action:                           generate_run_action(desired_lrp_builder),
          monitor:                          generate_monitor_action(desired_lrp_builder),
          root_fs:                          desired_lrp_builder.root_fs,
          setup:                            desired_lrp_builder.setup,
          domain:                           APP_LRP_DOMAIN,
          volume_mounts:                    generate_volume_mounts,
          PlacementTags:                    [IsolationSegmentSelector.for_space(process.space)],
          check_definition:                 generate_healthcheck_definition(desired_lrp_builder),
          routes:                           ::Diego::Bbs::Models::ProtoRoutes.new(routes: routes),
          max_pids:                         @config[:diego][:pid_limit],
          certificate_properties:           ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: ["app:#{process.app.guid}"]
          ),
          image_username:                   process.current_droplet.docker_receipt_username,
          image_password:                   process.current_droplet.docker_receipt_password,
        )
      end

      def build_app_lrp_update(existing_lrp)
        routes = generate_routes(routing_info)

        existing_routes = existing_lrp.routes
        ssh_route       = existing_routes.routes.find { |r| r.key == SSH_ROUTES_KEY }
        routes << ssh_route

        ::Diego::Bbs::Models::DesiredLRPUpdate.new(
          instances:  process.instances,
          annotation: process.updated_at.to_f.to_s,
          routes:     ::Diego::Bbs::Models::ProtoRoutes.new(routes: routes)
        )
      end

      private

      attr_reader :config, :process, :ssh_key

      def routing_info
        @routing_info ||= Protocol::RoutingInfo.new(process).routing_info
      end

      def health_check_timeout_in_seconds
        process.health_check_timeout || config[:default_health_check_timeout]
      end

      def generate_routes(info)
        http_routes = (info['http_routes'] || []).map do |i|
          {
            hostnames:         [i['hostname']],
            port:              i['port'],
            route_service_url: i['route_service_url'],
            isolation_segment: IsolationSegmentSelector.for_space(process.space),
          }
        end

        [
          ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
            key:   CF_ROUTES_KEY,
            value: MultiJson.dump(http_routes)
          ),
          ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
            key:   TCP_ROUTES_KEY,
            value: MultiJson.dump((info['tcp_routes'] || []))
          )
        ]
      end

      def allow_ssh?
        process.enable_ssh
      end

      def generate_volume_mounts
        app_volume_mounts   = Protocol::AppVolumeMounts.new(process.app).as_json
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

      def generate_app_action(start_command, user, environment_variables)
        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/launcher',
                 args:            [
                   'app',
                   start_command || '',
                   process.execution_metadata,
                 ],
                 env:             environment_variables,
                 log_source:      "APP/PROC/#{process.type.upcase}",
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit),
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
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit),
        ))
      end

      def generate_environment_variables(lrp_builder)
        environment_variables = lrp_builder.port_environment_variables.clone

        env = Environment.new(process, EnvironmentVariableGroup.running.environment_json).as_json
        env.each do |i|
          environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
        end
        environment_variables
      end

      def generate_run_action(lrp_builder)
        environment_variables = generate_environment_variables(lrp_builder)

        actions = []
        actions << generate_app_action(lrp_builder.start_command, lrp_builder.action_user, environment_variables)
        actions << generate_ssh_action(lrp_builder.action_user, environment_variables) if allow_ssh?
        codependent(actions)
      end

      def generate_healthcheck_definition(lrp_builder)
        return unless MONITORED_HEALTH_CHECK_TYPES.include?(process.health_check_type)

        desired_ports = lrp_builder.ports
        checks        = []
        desired_ports.each_with_index do |port, index|
          checks << build_check(port, index)
        end

        ::Diego::Bbs::Models::CheckDefinition.new(checks: checks)
      end

      def build_check(port, index)
        if process.health_check_type == 'http' && index == 0
          ::Diego::Bbs::Models::Check.new(http_check:
            ::Diego::Bbs::Models::HTTPCheck.new(
              path: process.health_check_http_endpoint,
              port: port,
            )
          )
        else
          ::Diego::Bbs::Models::Check.new(tcp_check:
            ::Diego::Bbs::Models::TCPCheck.new(
              port: port,
            )
          )
        end
      end

      def generate_monitor_action(lrp_builder)
        return unless MONITORED_HEALTH_CHECK_TYPES.include?(process.health_check_type)

        desired_ports = lrp_builder.ports
        actions       = []
        desired_ports.each_with_index do |port, index|
          actions << build_action(lrp_builder, port, index)
        end

        action(timeout(parallel(actions), timeout_ms: 1000 * 10.minutes))
      end

      def build_action(lrp_builder, port, index)
        extra_args = []
        if process.health_check_type == 'http' && index == 0
          extra_args << "-uri=#{process.health_check_http_endpoint}"
        end

        ::Diego::Bbs::Models::RunAction.new(
          user:                lrp_builder.action_user,
          path:                '/tmp/lifecycle/healthcheck',
          args:                ["-port=#{port}"].concat(extra_args),
          resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit),
          log_source:          HEALTH_LOG_SOURCE,
          suppress_log_output: true,
        )
      end

      def generate_egress_rules
        egress_rules = Diego::EgressRules.new
        egress_rules.running(process).map do |rule|
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     rule['protocol'],
            destinations: rule['destinations'],
            ports:        rule['ports'],
            port_range:   rule['port_range'],
            icmp_info:    rule['icmp_info'],
            log:          rule['log'],
            annotations:  rule['annotations'],
          )
        end
      end

      def generate_network
        Protocol::ContainerNetworkInfo.new(process.app).to_bbs_network
      end

      def file_descriptor_limit
        process.file_descriptors == 0 ? DEFAULT_FILE_DESCRIPTOR_LIMIT : process.file_descriptors
      end
    end
  end
end
