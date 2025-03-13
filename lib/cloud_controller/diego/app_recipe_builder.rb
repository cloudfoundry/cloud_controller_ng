require 'cloud_controller/diego/protocol/app_volume_mounts'
require 'cloud_controller/diego/protocol/container_network_info'
require 'cloud_controller/diego/protocol/routing_info'
require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/docker/desired_lrp_builder'
require 'cloud_controller/diego/cnb/desired_lrp_builder'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/ssh_key'
require 'cloud_controller/diego/service_binding_files_builder'
require 'credhub/config_helpers'
require 'models/helpers/health_check_types'
require 'cloud_controller/diego/main_lrp_action_builder'

module VCAP::CloudController
  module Diego
    class AppRecipeBuilder
      include ::Diego::ActionBuilder

      METRIC_TAG_VALUE = ::Diego::Bbs::Models::MetricTagValue

      MONITORED_HEALTH_CHECK_TYPES = [HealthCheckTypes::PORT, HealthCheckTypes::HTTP, ''].map(&:freeze).freeze
      MONITORED_READINESS_HEALTH_CHECK_TYPES = [HealthCheckTypes::PORT, HealthCheckTypes::HTTP].map(&:freeze).freeze

      def initialize(config:, process:, ssh_key: SSHKey.new)
        @config  = config
        @process = process
        @ssh_key = ssh_key
      end

      def build_app_lrp
        ::Diego::Bbs::Models::DesiredLRP.new(app_lrp_arguments)
      end

      def build_app_lrp_update(existing_lrp)
        routes = generate_routes(routing_info)

        existing_routes = existing_lrp.routes
        ssh_route = existing_routes.routes[SSH_ROUTES_KEY]
        routes[SSH_ROUTES_KEY] = ssh_route if ssh_route

        ::Diego::Bbs::Models::DesiredLRPUpdate.new(
          instances: process.instances,
          annotation: process.updated_at.to_f.to_s,
          metric_tags: metric_tags(process),
          routes: ::Diego::Bbs::Models::ProtoRoutes.new(routes:)
        )
      end

      private

      attr_reader :config, :process, :ssh_key

      def app_lrp_arguments
        desired_lrp_builder = LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_lrp_builder(config, process)
        ports = desired_lrp_builder.ports.dup
        routes = generate_routes(routing_info)

        if allow_ssh?
          ports << DEFAULT_SSH_PORT

          routes[SSH_ROUTES_KEY] = Oj.dump({
                                             container_port: DEFAULT_SSH_PORT,
                                             private_key: ssh_key.private_key,
                                             host_fingerprint: ssh_key.fingerprint
                                           })
        end

        {
          process_guid: Diego::ProcessGuid.from_process(process),
          instances: process.desired_instances,
          environment_variables: desired_lrp_builder.global_environment_variables,
          start_timeout_ms: health_check_timeout_in_seconds * 1000,
          disk_mb: process.disk_quota,
          memory_mb: process.memory, # sums up
          log_rate_limit: ::Diego::Bbs::Models::LogRateLimit.new(bytes_per_second: process.log_rate_limit),
          privileged: desired_lrp_builder.privileged?,
          ports: ports,
          log_source: LRP_LOG_SOURCE,
          log_guid: process.app_guid,
          metrics_guid: process.app_guid,
          metric_tags: metric_tags(process),
          annotation: process.updated_at.to_f.to_s,
          egress_rules: Diego::EgressRules.new.running_protobuf_rules(process),
          cached_dependencies: desired_lrp_builder.cached_dependencies,
          legacy_download_user: desired_lrp_builder.action_user,
          trusted_system_certificates_path: RUNNING_TRUSTED_SYSTEM_CERT_PATH,
          network: generate_network,
          cpu_weight: TaskCpuWeightCalculator.new(memory_in_mb: process.memory).calculate,
          action: MainLRPActionBuilder.build(process, desired_lrp_builder, ssh_key),
          monitor: generate_monitor_action(desired_lrp_builder),
          root_fs: desired_lrp_builder.root_fs,
          setup: desired_lrp_builder.setup,
          image_layers: desired_lrp_builder.image_layers,
          domain: APP_LRP_DOMAIN,
          volume_mounts: generate_volume_mounts,
          PlacementTags: Array(IsolationSegmentSelector.for_space(process.space)),
          check_definition: generate_healthcheck_definition(desired_lrp_builder),
          routes: ::Diego::Bbs::Models::ProtoRoutes.new(routes:),
          max_pids: @config.get(:diego, :pid_limit),
          certificate_properties: ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: ["organization:#{process.organization.guid}", "space:#{process.space.guid}", "app:#{process.app_guid}"]
          ),
          image_username: process.desired_droplet.docker_receipt_username,
          image_password: process.desired_droplet.docker_receipt_password,
          volume_mounted_files: ServiceBindingFilesBuilder.build(process)
        }.compact
      end

      def metric_tags(process)
        tags = {
          'source_id' => METRIC_TAG_VALUE.new(static: process.app_guid),
          'process_id' => METRIC_TAG_VALUE.new(static: process.guid),
          'process_type' => METRIC_TAG_VALUE.new(static: process.type),
          'process_instance_id' => METRIC_TAG_VALUE.new(dynamic: METRIC_TAG_VALUE::DynamicValue::INSTANCE_GUID),
          'instance_id' => METRIC_TAG_VALUE.new(dynamic: METRIC_TAG_VALUE::DynamicValue::INDEX),
          'organization_id' => METRIC_TAG_VALUE.new(static: process.organization.guid),
          'space_id' => METRIC_TAG_VALUE.new(static: process.space.guid),
          'app_id' => METRIC_TAG_VALUE.new(static: process.app_guid),
          'organization_name' => METRIC_TAG_VALUE.new(static: process.organization.name),
          'space_name' => METRIC_TAG_VALUE.new(static: process.space.name),
          'app_name' => METRIC_TAG_VALUE.new(static: process.app.name)
        }

        metric_tag_label_prefixes = Config.config.get(:custom_metric_tag_prefix_list)
        unless metric_tag_label_prefixes.empty?
          # These should not be overridden by app developers.  This list is based on
          # https://github.com/cloudfoundry/loggregator-agent-release/blob/8b714dc6f09cfa8a67d78ec974b77c0d7642f5a3/src/pkg/egress/v1/tagger.go#L32-L44
          # and is not expected to change
          reserved_key_names = %w[deployment index ip job]

          process.app.labels.
            select do |label|
              metric_tag_label_prefixes.include?(label.key_prefix) && !tags.key?(label.key_name)
            end.
            reject do |label|
              reserved_key_names.include?(label.key_name)
            end.
            each do |label|
              tags[label.key_name] = METRIC_TAG_VALUE.new(static: label.value)
            end
        end

        tags
      end

      def routing_info
        @routing_info ||= Protocol::RoutingInfo.new(process).routing_info
      end

      def health_check_timeout_in_seconds
        process.health_check_timeout || config.get(:default_health_check_timeout)
      end

      def generate_routes(info)
        http_routes = (info['http_routes'] || []).map do |i|
          http_route = {
            hostnames: [i['hostname']],
            port: i['port'],
            route_service_url: i['route_service_url'],
            isolation_segment: IsolationSegmentSelector.for_space(process.space),
            protocol: i['protocol']
          }
          http_route[:options] = i['options'] if i['options']
          http_route
        end

        {
          CF_ROUTES_KEY => Oj.dump(http_routes),
          TCP_ROUTES_KEY => Oj.dump((info['tcp_routes'] || [])),
          INTERNAL_ROUTES_KEY => Oj.dump((info['internal_routes'] || []))
        }
      end

      def allow_ssh?
        process.enable_ssh
      end

      def generate_volume_mounts
        app_volume_mounts   = Protocol::AppVolumeMounts.new(process.app).as_json
        proto_volume_mounts = []

        app_volume_mounts.each do |volume_mount|
          proto_volume_mount = ::Diego::Bbs::Models::VolumeMount.new(
            driver: volume_mount['driver'],
            container_dir: volume_mount['container_dir'],
            mode: volume_mount['mode']
          )

          mount_config              = volume_mount['device']['mount_config'].present? ? volume_mount['device']['mount_config'].to_json : ''
          proto_volume_mount.shared = ::Diego::Bbs::Models::SharedDevice.new(
            volume_id: volume_mount['device']['volume_id'],
            mount_config: mount_config
          )
          proto_volume_mounts.append(proto_volume_mount)
        end

        proto_volume_mounts
      end

      def generate_healthcheck_definition(lrp_builder)
        checks = generate_liveness_and_startup_health_check_defintion(lrp_builder)
        readiness_checks = generate_readiness_health_check_definition(lrp_builder)

        params = {}
        params[:checks] = checks unless checks.empty?
        params[:readiness_checks] = readiness_checks unless readiness_checks.empty?
        ::Diego::Bbs::Models::CheckDefinition.new(**params) unless params.empty?
      end

      def generate_readiness_health_check_definition(lrp_builder)
        return [] unless MONITORED_READINESS_HEALTH_CHECK_TYPES.include?(process.readiness_health_check_type)

        ports = lrp_builder.ports
        readiness_checks = []
        ports.each_with_index do |port, index|
          readiness_checks << build_readiness_check(port, index)
        end
        readiness_checks
      end

      def generate_liveness_and_startup_health_check_defintion(lrp_builder)
        return [] unless MONITORED_HEALTH_CHECK_TYPES.include?(process.health_check_type)

        desired_ports = lrp_builder.ports
        checks        = []
        desired_ports.each_with_index do |port, index|
          checks << build_check(port, index)
        end

        checks
      end

      def build_readiness_check(port, index)
        timeout_ms = (process.readiness_health_check_invocation_timeout || 0) * 1000
        interval_ms = (process.readiness_health_check_interval || 0) * 1000

        if process.readiness_health_check_type == HealthCheckTypes::HTTP && index == 0
          ::Diego::Bbs::Models::Check.new(http_check:
            ::Diego::Bbs::Models::HTTPCheck.new(
              path: process.readiness_health_check_http_endpoint,
              port: port,
              request_timeout_ms: timeout_ms,
              interval_ms: interval_ms
            ))
        else
          ::Diego::Bbs::Models::Check.new(tcp_check:
            ::Diego::Bbs::Models::TCPCheck.new(
              port: port,
              connect_timeout_ms: timeout_ms,
              interval_ms: interval_ms
            ))
        end
      end

      def build_check(port, index)
        timeout_ms = (process.health_check_invocation_timeout || 0) * 1000
        interval_ms = (process.health_check_interval || 0) * 1000

        if process.health_check_type == HealthCheckTypes::HTTP && index == 0
          ::Diego::Bbs::Models::Check.new(http_check:
            ::Diego::Bbs::Models::HTTPCheck.new(
              path: process.health_check_http_endpoint,
              port: port,
              request_timeout_ms: timeout_ms,
              interval_ms: interval_ms
            ))
        else
          ::Diego::Bbs::Models::Check.new(tcp_check:
            ::Diego::Bbs::Models::TCPCheck.new(
              port: port,
              connect_timeout_ms: timeout_ms,
              interval_ms: interval_ms
            ))
        end
      end

      def generate_monitor_action(lrp_builder)
        return unless MONITORED_HEALTH_CHECK_TYPES.include?(process.health_check_type)

        desired_ports = lrp_builder.ports
        actions       = []
        desired_ports.each_with_index do |port, index|
          actions << build_action(lrp_builder, port, index)
        end

        action(timeout(parallel(actions), timeout_ms: 10.minutes.in_milliseconds))
      end

      def build_action(lrp_builder, port, index)
        extra_args = []
        extra_args << "-uri=#{process.health_check_http_endpoint}" if process.health_check_type == HealthCheckTypes::HTTP && index == 0

        extra_args << "-timeout=#{process.health_check_invocation_timeout}s" if process.health_check_invocation_timeout

        ::Diego::Bbs::Models::RunAction.new(
          user: lrp_builder.action_user,
          path: '/tmp/lifecycle/healthcheck',
          args: ["-port=#{port}"].concat(extra_args),
          resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: process.file_descriptors),
          log_source: HEALTH_LOG_SOURCE,
          suppress_log_output: true
        )
      end

      def generate_network
        Protocol::ContainerNetworkInfo.new(process.app, Protocol::ContainerNetworkInfo::APP).to_bbs_network
      end
    end
  end
end
