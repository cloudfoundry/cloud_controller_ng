require 'diego/action_builder'

module VCAP::CloudController
  module Diego
    class RecipeBuilder
      include ::Diego::ActionBuilder

      STAGING_TASK_CPU_WEIGHT = 50

      def initialize
        @egress_rules = Diego::EgressRules.new
      end

      # rubocop:disable CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength
      def build_staging_task(config, staging_details)
        env = VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(staging_details.environment_variables)
        logger.debug2("staging environment: #{env.map { |e| e['name'] }}")

        lifecycle_type = staging_details.droplet.lifecycle_type
        lifecycle_data = LifecycleProtocol.protocol_for_type(lifecycle_type).lifecycle_data(staging_details)

        upload_droplet_uri       = URI(config[:diego][:cc_uploader_url])
        upload_droplet_uri.path  = "/v1/droplet/#{staging_details.droplet.guid}"
        upload_droplet_uri.query = {
          'cc-droplet-upload-uri' => lifecycle_data[:droplet_upload_uri],
          'timeout'               => config[:staging][:timeout_in_seconds],
        }.to_param

        upload_buildpack_artifacts_cache_uri       = URI(config[:diego][:cc_uploader_url])
        upload_buildpack_artifacts_cache_uri.path  = "/v1/build_artifacts/#{staging_details.droplet.guid}"
        upload_buildpack_artifacts_cache_uri.query = {
          'cc-build-artifacts-upload-uri' => lifecycle_data[:build_artifacts_cache_upload_uri],
          'timeout'                       => config[:staging][:timeout_in_seconds],
        }.to_param

        stack = if lifecycle_type == Lifecycles::BUILDPACK
                  lifecycle_data[:stack]
                elsif lifecycle_type == Lifecycles::DOCKER
                  config[:diego][:docker_staging_stack]
                end

        lifecycle_bundles = {}
        config[:diego][:lifecycle_bundles].each do |bundle|
          segments                       = bundle.split(':', 2)
          lifecycle_bundles[segments[0]] = segments[1]
        end
        lifecycle_bundle = if lifecycle_type == Lifecycles::BUILDPACK
                             lifecycle_bundles["#{lifecycle_type}/#{stack}"]
                           elsif lifecycle_type == Lifecycles::DOCKER
                             lifecycle_bundles['docker']
                           end
        raise CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed: no compiler defined for requested stack') unless lifecycle_bundle
        lifecycle_bundle_url = URI(lifecycle_bundle)

        case lifecycle_bundle_url.scheme
        when 'http', 'https'
          lifecycle_cached_dependency_uri = lifecycle_bundle_url
        when nil
          lifecycle_cached_dependency_uri = URI(config[:diego][:file_server_url])
          lifecycle_cached_dependency_uri.path = "/v1/static/#{lifecycle_bundle}"
        else
          raise CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed: invalid compiler URI')
        end

        lifecycle_cached_dependency = if lifecycle_type == Lifecycles::BUILDPACK
                                        ::Diego::Bbs::Models::CachedDependency.new(
                                          from:      lifecycle_cached_dependency_uri.to_s,
                                          to:        '/tmp/lifecycle',
                                          cache_key: "buildpack-#{stack}-lifecycle",
                                        )
                                      elsif lifecycle_type == Lifecycles::DOCKER
                                        ::Diego::Bbs::Models::CachedDependency.new(
                                          from:      lifecycle_cached_dependency_uri.to_s,
                                          to:        '/tmp/docker_app_lifecycle',
                                          cache_key: 'docker-lifecycle',
                                        )
                                      end

        cached_dependencies = [lifecycle_cached_dependency]

        if lifecycle_type == Lifecycles::BUILDPACK
          cached_dependencies.concat(lifecycle_data[:buildpacks].map do |buildpack|
            next if buildpack[:name] == 'custom'

            ::Diego::Bbs::Models::CachedDependency.new(
              name:      buildpack[:name],
              from:      buildpack[:url],
              to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest(buildpack[:key])}",
              cache_key: buildpack[:key],
            )
          end.compact)
        end

        run_action = if lifecycle_type == Lifecycles::BUILDPACK
                       ::Diego::Bbs::Models::RunAction.new(
                         path:            '/tmp/lifecycle/builder',
                         user:            'vcap',
                         args:            [
                           "-buildpackOrder=#{lifecycle_data[:buildpacks].map { |i| i[:key] }.join(',')}",
                           "-skipCertVerify=#{config[:skip_cert_verify]}",
                           "-skipDetect=#{!!lifecycle_data[:buildpacks].first[:skip_detect]}",
                         ],
                         resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config[:staging][:minimum_staging_file_descriptor_limit]),
                         env:             env.map do |i|
                           ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
                         end.concat([::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CF_STACK', value: stack)])
                       )
                     elsif lifecycle_type == Lifecycles::DOCKER
                       if config[:diego][:insecure_docker_registry_list].count > 0
                         insecure_registries = "-insecureDockerRegistries=#{config[:diego][:insecure_docker_registry_list].join(',')}"
                       end

                       ::Diego::Bbs::Models::RunAction.new(
                         path:            '/tmp/docker_app_lifecycle/builder',
                         user:            'vcap',
                         args:            [
                           '-outputMetadataJSONFilename=/tmp/docker-result/result.json',
                           "-dockerRef=#{lifecycle_data[:docker_image]}",
                         ].concat([insecure_registries]).compact,
                         resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config[:staging][:minimum_staging_file_descriptor_limit]),
                         env:             env.map do |i|
                           ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
                         end
                       )
                     end

        stager_completion_callback_url      = URI(config[:diego][:stager_url])
        stager_completion_callback_url.path = "/v1/staging/#{staging_details.droplet.guid}/completed"

        build_artifacts_cache_download_action = if lifecycle_data[:build_artifacts_cache_download_uri]
                                                  ::Diego::Bbs::Models::DownloadAction.new(
                                                    artifact: 'build artifacts cache',
                                                    from:     lifecycle_data[:build_artifacts_cache_download_uri],
                                                    to:       '/tmp/cache',
                                                    user:     'vcap'
                                                  )
                                                end

        result_file = if lifecycle_type == Lifecycles::BUILDPACK
                        '/tmp/result.json'
                      elsif lifecycle_type == Lifecycles::DOCKER
                        '/tmp/docker-result/result.json'
                      end

        actions = []
        if lifecycle_type == Lifecycles::BUILDPACK
          actions << ::Diego::Bbs::Models::DownloadAction.new(
            artifact: 'app package',
            from:     lifecycle_data[:app_bits_download_uri],
            to:       '/tmp/app',
            user:     'vcap'
          )
          actions << build_artifacts_cache_download_action
          actions << run_action
          actions << emit_progress(
            parallel([
              ::Diego::Bbs::Models::UploadAction.new(
                user:     'vcap',
                artifact: 'droplet',
                from:     '/tmp/droplet',
                to:       upload_droplet_uri.to_s,
              ),

              ::Diego::Bbs::Models::UploadAction.new(
                user:     'vcap',
                artifact: 'build artifacts cache',
                from:     '/tmp/output-cache',
                to:       upload_buildpack_artifacts_cache_uri.to_s,
              ),
            ]),
            start_message:          'Uploading droplet, build artifacts cache...',
            success_message:        'Uploading complete',
            failure_message_prefix: 'Uploading failed'
          )
        elsif lifecycle_type == Lifecycles::DOCKER
          actions << emit_progress(
            run_action,
            start_message:          'Staging...',
            success_message:        'Staging Complete',
            failure_message_prefix: 'Staging Failed'
          )
        end

        ::Diego::Bbs::Models::TaskDefinition.new({
          root_fs:                          "preloaded:#{stack}",
          log_guid:                         staging_details.package.app_guid,
          log_source:                       'STG',
          result_file:                      result_file,
          privileged:                       config[:diego][:use_privileged_containers_for_staging],
          trusted_system_certificates_path: '/etc/cf-system-certificates',

          annotation:                       {
                                              lifecycle:           lifecycle_type,
                                              completion_callback: staging_completion_callback(staging_details, config).to_s
                                            }.to_json,

          memory_mb:                        staging_details.staging_memory_in_mb,
          disk_mb:                          staging_details.staging_disk_in_mb,
          cpu_weight:                       STAGING_TASK_CPU_WEIGHT,
          legacy_download_user:             'vcap',

          completion_callback_url:          stager_completion_callback_url.to_s,

          environment_variables:            [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: 'en_US.UTF-8')],

          egress_rules:                     @egress_rules.staging.map do |rule|
            ::Diego::Bbs::Models::SecurityGroupRule.new(
              protocol:     rule['protocol'],
              destinations: rule['destinations'],
              ports:        rule['ports'],
              port_range:   rule['port_range'],
              icmp_info:    rule['icmp_info'],
              log:          rule['log'],
            )
          end,

          cached_dependencies:              cached_dependencies,

          action:                           timeout(serial(actions.compact), timeout_ms: config[:staging][:timeout_in_seconds].to_i * 1000)
        })
      end
      # rubocop:enable CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength

      private

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
