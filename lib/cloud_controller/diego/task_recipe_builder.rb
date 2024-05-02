require 'diego/action_builder'
require 'cloud_controller/diego/lifecycle_bundle_uri_generator'
require 'cloud_controller/diego/buildpack/task_action_builder'
require 'cloud_controller/diego/docker/task_action_builder'
require 'cloud_controller/diego/cnb/task_action_builder'
require 'cloud_controller/diego/bbs_environment_builder'
require 'cloud_controller/diego/task_completion_callback_generator'
require 'cloud_controller/diego/task_cpu_weight_calculator'

module VCAP::CloudController
  module Diego
    class TaskRecipeBuilder
      include ::Diego::ActionBuilder

      METRIC_TAG_VALUE = ::Diego::Bbs::Models::MetricTagValue

      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      def build_app_task(config, task)
        task_completion_callback = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(config).generate(task)
        app_volume_mounts        = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(task.app).as_json
        task_action_builder      = LifecycleProtocol.protocol_for_type(task.droplet.lifecycle_type).task_action_builder(config, task)

        ::Diego::Bbs::Models::TaskDefinition.new({
          completion_callback_url: task_completion_callback,
          cpu_weight: cpu_weight(task),
          disk_mb: task.disk_in_mb,
          egress_rules: @egress_rules.running_protobuf_rules(task.app),
          log_guid: task.app_guid,
          log_rate_limit: ::Diego::Bbs::Models::LogRateLimit.new(bytes_per_second: task.log_rate_limit),
          log_source: TASK_LOG_SOURCE,
          max_pids: config.get(:diego, :pid_limit),
          memory_mb: task.memory_in_mb,
          metric_tags: metric_tags(task),
          network: generate_network(task, Protocol::ContainerNetworkInfo::TASK),
          privileged: config.get(:diego, :use_privileged_containers_for_running),
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,
          volume_mounts: generate_volume_mounts(app_volume_mounts),
          action: task_action_builder.action,
          legacy_download_user: LEGACY_DOWNLOAD_USER,
          image_layers: task_action_builder.image_layers,
          cached_dependencies: task_action_builder.cached_dependencies,
          root_fs: task_action_builder.stack,
          environment_variables: task_action_builder.task_environment_variables,
          placement_tags: [VCAP::CloudController::IsolationSegmentSelector.for_space(task.space)].compact,
          certificate_properties: ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: [
              "organization:#{task.app.organization.guid}",
              "space:#{task.app.space_guid}",
              "app:#{task.app_guid}"
            ]
          ),
          image_username: task.droplet.docker_receipt_username,
          image_password: task.droplet.docker_receipt_password
        }.compact)
      end

      def build_staging_task(config, staging_details)
        lifecycle_type = staging_details.lifecycle.type
        action_builder = LifecycleProtocol.protocol_for_type(lifecycle_type).staging_action_builder(config, staging_details)

        ::Diego::Bbs::Models::TaskDefinition.new({
          completion_callback_url: staging_completion_callback(config, staging_details),
          cpu_weight: STAGING_TASK_CPU_WEIGHT,
          disk_mb: staging_details.staging_disk_in_mb,
          egress_rules: @egress_rules.staging_protobuf_rules(app_guid: staging_details.package.app_guid),
          log_guid: staging_details.package.app_guid,
          log_source: STAGING_LOG_SOURCE,
          metric_tags: metric_tags(staging_details.package),
          memory_mb: staging_details.staging_memory_in_mb,
          log_rate_limit: ::Diego::Bbs::Models::LogRateLimit.new(bytes_per_second: staging_details.staging_log_rate_limit_bytes_per_second),
          network: generate_network(staging_details.package, Protocol::ContainerNetworkInfo::STAGING),
          privileged: config.get(:diego, :use_privileged_containers_for_staging),
          result_file: STAGING_RESULT_FILE,
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,
          root_fs: action_builder.stack,
          action: timeout(action_builder.action, timeout_ms: config.get(:staging, :timeout_in_seconds).to_i * 1000),
          environment_variables: action_builder.task_environment_variables,
          legacy_download_user: LEGACY_DOWNLOAD_USER,
          image_layers: action_builder.image_layers,
          cached_dependencies: action_builder.cached_dependencies,
          placement_tags: find_staging_isolation_segment(staging_details),
          max_pids: config.get(:diego, :pid_limit),
          certificate_properties: ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: [
              "organization:#{staging_details.package.app.organization.guid}",
              "space:#{staging_details.package.app.space_guid}",
              "app:#{staging_details.package.app_guid}"
            ]
          ),
          image_username: staging_details.package.docker_username,
          image_password: staging_details.package.docker_password
        }.compact)
      end

      private

      def metric_tags(source)
        {
          'source_id' => METRIC_TAG_VALUE.new(static: source.app_guid),
          'organization_id' => METRIC_TAG_VALUE.new(static: source.app.organization_guid),
          'space_id' => METRIC_TAG_VALUE.new(static: source.space_guid),
          'app_id' => METRIC_TAG_VALUE.new(static: source.app_guid),
          'organization_name' => METRIC_TAG_VALUE.new(static: source.app.organization.name),
          'space_name' => METRIC_TAG_VALUE.new(static: source.space.name),
          'app_name' => METRIC_TAG_VALUE.new(static: source.app.name)
        }
      end

      def staging_completion_callback(config, staging_details)
        port   = config.get(:tls_port)
        scheme = 'https'

        host_port = "#{config.get(:internal_service_hostname)}:#{port}"
        path      = "/internal/v3/staging/#{staging_details.staging_guid}/build_completed?start=#{staging_details.start_after_staging}"
        "#{scheme}://#{host_port}#{path}"
      end

      def cpu_weight(task)
        TaskCpuWeightCalculator.new(memory_in_mb: task.memory_in_mb).calculate
      end

      def generate_network(task, container_workload)
        Protocol::ContainerNetworkInfo.new(task.app, container_workload).to_bbs_network
      end

      def find_staging_isolation_segment(staging_details)
        if staging_details.isolation_segment
          [staging_details.isolation_segment]
        else
          []
        end
      end

      def generate_volume_mounts(app_volume_mounts)
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

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
