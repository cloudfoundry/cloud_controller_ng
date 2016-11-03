module VCAP::CloudController
  module Diego
    module Docker
      class StagingActionBuilder
        include ::Diego::ActionBuilder

        attr_reader :config, :lifecycle_data, :env

        def initialize(config, lifecycle_data, env)
          @config         = config
          @lifecycle_data = lifecycle_data
          @env            = env
        end

        def action
          run_args = [
            "-outputMetadataJSONFilename=#{STAGING_RESULT_FILE}",
            "-dockerRef=#{lifecycle_data[:docker_image]}",
          ]

          if config[:diego][:insecure_docker_registry_list].count > 0
            insecure_registries = "-insecureDockerRegistries=#{config[:diego][:insecure_docker_registry_list].join(',')}"
            run_args << insecure_registries
          end

          stage_action = ::Diego::Bbs::Models::RunAction.new(
            path:            '/tmp/docker_app_lifecycle/builder',
            user:            'vcap',
            args:            run_args,
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config[:staging][:minimum_staging_file_descriptor_limit]),
            env:             env
          )

          emit_progress(
            stage_action,
            start_message:          'Staging...',
            success_message:        'Staging Complete',
            failure_message_prefix: 'Staging Failed'
          )
        end

        def cached_dependencies
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from:      lifecycle_cached_dependency_uri,
              to:        '/tmp/docker_app_lifecycle',
              cache_key: 'docker-lifecycle',
            )
          ]
        end

        def stack
          config[:diego][:docker_staging_stack]
        end

        def task_environment_variables
        end

        private

        def lifecycle_cached_dependency_uri
          lifecycle_bundle = config[:diego][:lifecycle_bundles][:docker]

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
          lifecycle_cached_dependency_uri.to_s
        end
      end
    end
  end
end
