require 'diego/action_builder'
require 'cloud_controller/diego/lifecycle_bundle_uri_generator'
require 'cloud_controller/diego/buildpack/task_action_builder'
require 'cloud_controller/diego/docker/task_action_builder'
require 'cloud_controller/diego/bbs_environment_builder'
require 'cloud_controller/diego/task_cpu_weight_calculator'

module VCAP::CloudController
  module Diego
    class TaskRecipeBuilder
      include ::Diego::ActionBuilder

      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      def build_app_task(config, task)
        task_completion_callback = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(config).generate(task)
        app_volume_mounts        = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(task.app).as_json
        task_action_builder      = LifecycleProtocol.protocol_for_type(task.droplet.lifecycle_type).task_action_builder(config, task)

        ::Diego::Bbs::Models::TaskDefinition.new(
          completion_callback_url:          task_completion_callback,
          cpu_weight:                       cpu_weight(task),
          disk_mb:                          task.disk_in_mb,
          egress_rules:                     generate_running_egress_rules(task.app),
          legacy_download_user:             STAGING_LEGACY_DOWNLOAD_USER,
          log_guid:                         task.app.guid,
          log_source:                       TASK_LOG_SOURCE,
          max_pids:                         config[:diego][:pid_limit],
          memory_mb:                        task.memory_in_mb,
          network:                          generate_network(task),
          privileged:                       config[:diego][:use_privileged_containers_for_running],
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,
          volume_mounts:                    generate_volume_mounts(app_volume_mounts),
          action:                           task_action_builder.action,
          cached_dependencies:              task_action_builder.cached_dependencies,
          root_fs:                          task_action_builder.stack,
          environment_variables:            task_action_builder.task_environment_variables,
          PlacementTags:                    [VCAP::CloudController::IsolationSegmentSelector.for_space(task.space)],
          certificate_properties:           ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: ["app:#{task.app.guid}"]
          ),
          image_username:                   task.droplet.docker_receipt_username,
          image_password:                   task.droplet.docker_receipt_password,
        )
      end

      def build_staging_task(config, staging_details)
        lifecycle_type = staging_details.lifecycle.type
        action_builder = LifecycleProtocol.protocol_for_type(lifecycle_type).staging_action_builder(config, staging_details)

        ::Diego::Bbs::Models::TaskDefinition.new(
          completion_callback_url:          staging_completion_callback(staging_details, config),
          cpu_weight:                       STAGING_TASK_CPU_WEIGHT,
          disk_mb:                          staging_details.staging_disk_in_mb,
          egress_rules:                     generate_egress_rules(staging_details),
          legacy_download_user:             STAGING_LEGACY_DOWNLOAD_USER,
          log_guid:                         staging_details.package.app_guid,
          log_source:                       STAGING_LOG_SOURCE,
          memory_mb:                        staging_details.staging_memory_in_mb,
          privileged:                       config[:diego][:use_privileged_containers_for_staging],
          result_file:                      STAGING_RESULT_FILE,
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,
          root_fs:                          "preloaded:#{action_builder.stack}",
          action:                           timeout(action_builder.action, timeout_ms: config[:staging][:timeout_in_seconds].to_i * 1000),
          environment_variables:            action_builder.task_environment_variables,
          cached_dependencies:              action_builder.cached_dependencies,
          PlacementTags:                    find_staging_isolation_segment(staging_details),
          max_pids:                         config[:diego][:pid_limit],
          certificate_properties:           ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: ["app:#{staging_details.package.app_guid}"]
          ),
          image_username:                   staging_details.package.docker_username,
          image_password:                   staging_details.package.docker_password,
        )
      end

      def staging_completion_callback(staging_details, config)
        port   = config[:tls_port]
        scheme = 'https'

        auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
        host_port = "#{config[:internal_service_hostname]}:#{port}"
        path      = "/internal/v3/staging/#{staging_details.staging_guid}/build_completed?start=#{staging_details.start_after_staging}"
        "#{scheme}://#{auth}@#{host_port}#{path}"
      end

      private

      def cpu_weight(task)
        TaskCpuWeightCalculator.new(memory_in_mb: task.memory_in_mb).calculate
      end

      def generate_network(task)
        Protocol::ContainerNetworkInfo.new(task.app).to_bbs_network
      end

      def find_staging_isolation_segment(staging_details)
        if staging_details.isolation_segment
          [staging_details.isolation_segment]
        else
          []
        end
      end

      def generate_egress_rules(staging_details)
        @egress_rules.staging(app_guid: staging_details.package.app_guid).map do |rule|
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

      def generate_running_egress_rules(process)
        @egress_rules.running(process).map do |rule|
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

      def generate_volume_mounts(app_volume_mounts)
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

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
