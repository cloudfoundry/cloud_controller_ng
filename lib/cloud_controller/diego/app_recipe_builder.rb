require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/docker/desired_lrp_builder'

module VCAP::CloudController
  module Diego
    class AppRecipeBuilder
      include ::Diego::ActionBuilder

      class MissingAppPort < StandardError
      end

      def build_app_lrp(config, process, app_request)
        desired_lrp_builder = LifecycleProtocol.protocol_for_type(process.app.lifecycle_type).desired_lrp_builder(config, app_request)

        ::Diego::Bbs::Models::DesiredLRP.new(
          process_guid: app_request['process_guid'],
          instances: app_request['num_instances'],
          environment_variables: [],
          start_timeout_ms: app_request['health_check_timeout_in_seconds'] * 1000,
          disk_mb: app_request['disk_mb'],
          memory_mb: app_request['memory_mb'],
          privileged: false,
          ports: extract_exposed_ports(app_request),
          log_source: LRP_LOG_SOURCE,
          log_guid: app_request['log_guid'],
          metrics_guid: app_request['log_guid'],
          annotation: app_request['etag'],
          egress_rules: generate_egress_rules(app_request['egress_rules']),
          cached_dependencies: desired_lrp_builder.cached_dependencies,
          legacy_download_user: 'root',
          trusted_system_certificates_path: RUNNING_TRUSTED_SYSTEM_CERT_PATH,
          network: generate_network(app_request['network']),
          cpu_weight: TaskCpuWeightCalculator.new(memory_in_mb: app_request['memory_mb']).calculate,
          action: action(
            ::Diego::Bbs::Models::CodependentAction.new(actions: generate_app_action(app_request))
          ),
          monitor: generate_monitor_action(app_request),
          root_fs: desired_lrp_builder.root_fs,
        )
      end

      private

      def extract_exposed_ports(app_request)
        if app_request['ports'].length > 0
          return app_request['ports']
        end
        execution_metadata = MultiJson.load(app_request['execution_metadata'])
        if execution_metadata['ports'].empty?
          return [DEFAULT_APP_PORT]
        end
        tcp_ports = execution_metadata['ports'].select { |port| port['protocol'] == 'tcp' }
        fail MissingAppPort if tcp_ports.empty?

        tcp_ports.map { |port| port['port'].to_i }
      end

      def generate_app_action(app_request)
        execution_metadata = MultiJson.load(app_request['execution_metadata'])
        desired_ports = extract_exposed_ports(app_request)
        environment_variables = []
        app_request['environment'].each do |i|
          environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
        end
        environment_variables << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: desired_ports.first.to_s)

        [
          action(
            ::Diego::Bbs::Models::RunAction.new(
              user: override_action_user(execution_metadata),
              path: '/tmp/lifecycle/launcher',
              args: [
                'app',
                app_request['start_command'],
                app_request['execution_metadata'],
              ],
              env: environment_variables,
              log_source: app_request['log_source'] || APP_LOG_SOURCE,
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
            )
          )
        ]
      end

      def generate_monitor_action(app_request)
        return unless ['', 'port'].include?(app_request['health_check_type'])
        execution_metadata = MultiJson.load(app_request['execution_metadata'])

        desired_ports = extract_exposed_ports(app_request)
        actions = []
        desired_ports.each do |port|
          actions << ::Diego::Bbs::Models::RunAction.new(
            user: override_action_user(execution_metadata),
            path: '/tmp/lifecycle/healthcheck',
            args: ["-port=#{port}"],
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: file_descriptor_limit(app_request['file_descriptors'])),
            log_source: HEALTH_LOG_SOURCE,
            suppress_log_output: true,
          )
        end

        action(timeout(parallel(actions), timeout_ms: 1000 * 30.seconds))
      end

      def generate_egress_rules(rules)
        rules.map do |rule|
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: rule['protocol'],
            destinations: rule['destinations'],
            ports: rule['ports'],
            port_range: rule['port_range'],
            icmp_info: rule['icmp_info'],
            log: rule['log'],
          )
        end
      end

      def generate_network(network_hash)
        network = ::Diego::Bbs::Models::Network.new(properties: [])

        network_hash['properties'].each do |key, value|
          network.properties << ::Diego::Bbs::Models::Network::PropertiesEntry.new(
            key: key,
            value: value,
          )
        end

        network
      end

      def file_descriptor_limit(file_descriptors)
        file_descriptors == 0 ? DEFAULT_FILE_DESCRIPTOR_LIMIT : file_descriptors
      end

      def override_action_user(execution_metadata)
        user = execution_metadata['user']
        if user.nil? || user.empty?
          'root'
        else
          user
        end
      end
    end
  end
end
