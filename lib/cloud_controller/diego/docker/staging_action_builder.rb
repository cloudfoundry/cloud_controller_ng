module VCAP::CloudController
  module Diego
    module Docker
      class StagingActionBuilder
        include ::Diego::ActionBuilder

        attr_reader :config, :staging_details

        def initialize(config, staging_details)
          @config          = config
          @staging_details = staging_details
        end

        def action
          run_args = [
            "-outputMetadataJSONFilename=#{STAGING_RESULT_FILE}",
            "-dockerRef=#{staging_details.package.image}",
          ]

          if config[:diego][:insecure_docker_registry_list].count.positive?
            insecure_registries = "-insecureDockerRegistries=#{config[:diego][:insecure_docker_registry_list].join(',')}"
            run_args << insecure_registries
          end

          stage_action = ::Diego::Bbs::Models::RunAction.new(
            path:            '/tmp/docker_app_lifecycle/builder',
            user:            'vcap',
            args:            run_args,
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config[:staging][:minimum_staging_file_descriptor_limit]),
            env:             BbsEnvironmentBuilder.build(staging_details.environment_variables)
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
              from:      LifecycleBundleUriGenerator.uri(config[:diego][:lifecycle_bundles][:docker]),
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
      end
    end
  end
end
