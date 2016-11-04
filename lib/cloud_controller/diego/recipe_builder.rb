require 'diego/action_builder'
require 'cloud_controller/diego/lifecycle_bundle_uri_generator'
require 'cloud_controller/diego/bbs_environment_builder'

module VCAP::CloudController
  module Diego
    class RecipeBuilder
      include ::Diego::ActionBuilder

      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      def build_staging_task(config, staging_details)
        lifecycle_type = staging_details.droplet.lifecycle_type
        action_builder = LifecycleProtocol.protocol_for_type(lifecycle_type).action_builder(config, staging_details)

        ::Diego::Bbs::Models::TaskDefinition.new(
          log_guid:                         staging_details.package.app_guid,
          log_source:                       STAGING_LOG_SOURCE,
          result_file:                      STAGING_RESULT_FILE,
          privileged:                       config[:diego][:use_privileged_containers_for_staging],
          annotation:                       generate_annotation(config, lifecycle_type, staging_details),
          memory_mb:                        staging_details.staging_memory_in_mb,
          disk_mb:                          staging_details.staging_disk_in_mb,
          cpu_weight:                       STAGING_TASK_CPU_WEIGHT,
          legacy_download_user:             STAGING_LEGACY_DOWNLOAD_USER,
          completion_callback_url:          stager_callback_url(config, staging_details),
          egress_rules:                     generate_egress_rules,
          trusted_system_certificates_path: STAGING_TRUSTED_SYSTEM_CERT_PATH,

          root_fs:                          "preloaded:#{action_builder.stack}",
          action:                           timeout(action_builder.action, timeout_ms: config[:staging][:timeout_in_seconds].to_i * 1000),
          environment_variables:            action_builder.task_environment_variables,
          cached_dependencies:              action_builder.cached_dependencies,
        )
      end

      private

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

      def generate_egress_rules
        @egress_rules.staging.map do |rule|
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
