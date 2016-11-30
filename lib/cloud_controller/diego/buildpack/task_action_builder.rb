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
          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: lifecycle_data[:droplet_uri],
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
            from: LifecycleBundleUriGenerator.uri(config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
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
