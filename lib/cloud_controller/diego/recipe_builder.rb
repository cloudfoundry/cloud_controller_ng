require 'diego/action_builder'
require 'cloud_controller/diego/lifecycle_bundle_uri_generator'
require 'cloud_controller/diego/bbs_environment_builder'

module VCAP::CloudController
  module Diego
    class RecipeBuilder
      include ::Diego::ActionBuilder

      class InvalidDownloadUri < StandardError; end

      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      def build_app_task(config, task)
        stack = task.droplet.buildpack_receipt_stack_name
        lifecycle_bundle_key = "buildpack/#{stack}".to_sym
        log_source = "APP/TASK/#{task.name}"
        blobstore_url_generator  = CloudController::DependencyLocator.instance.blobstore_url_generator
        task_completion_callback = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(config).generate(task)

        download_url = blobstore_url_generator.droplet_download_url(task.droplet)
        raise InvalidDownloadUri.new("Failed to get blobstore download url for droplet #{task.droplet.guid}") unless download_url

        app_volume_mounts = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(task.app).as_json

        ::Diego::Bbs::Models::TaskDefinition.new(
          completion_callback_url: task_completion_callback,
          cpu_weight: 25,
          disk_mb: task.disk_in_mb,
          egress_rules: generate_running_egress_rules(task.app),
          legacy_download_user: STAGING_LEGACY_DOWNLOAD_USER,
          log_guid: task.app.guid,
          log_source: log_source,
          memory_mb: task.memory_in_mb,
          privileged: config[:diego][:use_privileged_containers_for_running],
          environment_variables: envs_for_diego(task.app, task),
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,

          root_fs: "preloaded:#{stack}",
          action: serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: download_url,
              to: '.',
              cache_key: '',
              user: 'vcap',
              checksum_algorithm: 'sha1',
              checksum_value: task.droplet.droplet_hash
            ),
            ::Diego::Bbs::Models::RunAction.new(
              user: 'vcap',
              path: '/tmp/lifecycle/launcher',
              args: ['app', task.command, ''],
              log_source:  log_source,
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: envs_for_diego(task.app, task)
            ),
          ]),
          cached_dependencies: [::Diego::Bbs::Models::CachedDependency.new(
            from:      LifecycleBundleUriGenerator.uri(config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
            to:        '/tmp/lifecycle',
            cache_key: "buildpack-#{stack}-lifecycle",
          )],
          volume_mounts: generate_volume_mounts(app_volume_mounts)
        )
      end

      def build_staging_task(config, staging_details)
        lifecycle_type = staging_details.droplet.lifecycle_type
        action_builder = LifecycleProtocol.protocol_for_type(lifecycle_type).staging_action_builder(config, staging_details)

        ::Diego::Bbs::Models::TaskDefinition.new(
          annotation:                       generate_annotation(config, lifecycle_type, staging_details),
          completion_callback_url:          stager_callback_url(config, staging_details),
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
        )
      end

      private

      def envs_for_diego(app, task)
        running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
        envs         = VCAP::CloudController::Diego::TaskEnvironment.new(app, task, app.space, running_envs).build
        diego_envs   = VCAP::CloudController::Diego::BbsEnvironmentBuilder.build(envs)

        logger.debug2("task environment: #{diego_envs.map(&:name)}")

        diego_envs
      end

      def generate_annotation(config, lifecycle_type, staging_details)
        {
          lifecycle:           lifecycle_type,
          completion_callback: staging_completion_callback(staging_details, config)
        }.to_json
      end

      def stager_callback_url(config, staging_details)
        stager_completion_callback_url      = URI(config[:diego][:stager_url])
        stager_completion_callback_url.path = "/v1/staging/#{staging_details.droplet.guid}/completed"
        stager_completion_callback_url.to_s
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
          )
        end
      end

      def generate_volume_mounts(app_volume_mounts)
        proto_volume_mounts = []
        app_volume_mounts.each do |volume_mount|
          proto_volume_mount = ::Diego::Bbs::Models::VolumeMount.new(
            driver: volume_mount['device']['driver'],
            container_dir: volume_mount['container_dir'],
            mode: volume_mount['mode']
          )

          a = volume_mount['device']['mount_config']
          mount_config = a.present? ? a.to_json : ''
          proto_volume_mount.shared = ::Diego::Bbs::Models::SharedDevice.new(
            volume_id: volume_mount['device']['volume_id'],
            mount_config: mount_config
          )
          proto_volume_mounts.append(proto_volume_mount)
        end

        proto_volume_mounts
      end

      def staging_completion_callback(staging_details, config)
        auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
        host_port = "#{config[:internal_service_hostname]}:#{config[:external_port]}"
        path      = "/internal/v3/staging/#{staging_details.droplet.guid}/droplet_completed?start=#{staging_details.start_after_staging}"
        "http://#{auth}@#{host_port}#{path}"
      end

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
