require 'diego/action_builder'
require 'cloud_controller/diego/task_environment_variable_collector'

module VCAP::CloudController
  module Diego
    module Buildpack
      class TaskActionBuilder
        include ::Diego::ActionBuilder

        def initialize(config, task, lifecycle_data)
          @config = config
          @task = task
          @lifecycle_data = lifecycle_data
        end

        def action
          download_droplet_action = ::Diego::Bbs::Models::DownloadAction.new(
            from: lifecycle_data[:droplet_uri],
            to: '.',
            cache_key: '',
            user: 'vcap',
          )
          if task.droplet.sha256_checksum
            download_droplet_action.checksum_algorithm = 'sha256'
            download_droplet_action.checksum_value = task.droplet.sha256_checksum
          else
            download_droplet_action.checksum_algorithm = 'sha1'
            download_droplet_action.checksum_value = task.droplet.droplet_hash
          end

          serial([
            download_droplet_action,
            ::Diego::Bbs::Models::RunAction.new(
              user: 'vcap',
              path: '/tmp/lifecycle/launcher',
              args: ['app', task.command, ''],
              log_source: "APP/TASK/#{task.name}",
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: task_environment_variables
            ),
          ])
        end

        def task_environment_variables
          TaskEnvironmentVariableCollector.for_task task
        end

        def stack
          "preloaded:#{lifecycle_stack}"
        end

        def cached_dependencies
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
            to: '/tmp/lifecycle',
            cache_key: "buildpack-#{lifecycle_stack}-lifecycle",
          )]
        end

        def lifecycle_bundle_key
          "buildpack/#{lifecycle_stack}".to_sym
        end

        private

        attr_reader :task, :lifecycle_data, :config

        def lifecycle_stack
          lifecycle_data[:stack]
        end
      end
    end
  end
end
