require 'diego/action_builder'
require 'cloud_controller/diego/docker/docker_uri_converter'
require 'cloud_controller/diego/task_environment_variable_collector'

module VCAP::CloudController
  module Diego
    module Docker
      class TaskActionBuilder
        def initialize(config, task, lifecycle_data)
          @task = task
          @lifecycle_data = lifecycle_data
          @config = config
        end

        def action
          launcher_args = ['app', task.command, '{}']
          launcher_args.push(encoded_credhub_url) if encoded_credhub_url.present?

          ::Diego::ActionBuilder.action(
            ::Diego::Bbs::Models::RunAction.new(
              user: 'root',
              path: '/tmp/lifecycle/launcher',
              args: launcher_args,
              log_source: "APP/TASK/#{task.name}",
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: task_environment_variables,
            )
          )
        end

        def task_environment_variables
          TaskEnvironmentVariableCollector.for_task task
        end

        def stack
          DockerURIConverter.new.convert(lifecycle_data[:droplet_path])
        end

        def lifecycle_bundle_key
          'docker'.to_sym
        end

        def cached_dependencies
          bundle = config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(bundle),
            to: '/tmp/lifecycle',
            cache_key: 'docker-lifecycle',
          )]
        end

        private

        attr_reader :config, :task, :lifecycle_data

        def encoded_credhub_url
          credhub_url = Config.config.get(:credhub_api, :url)
          return unless credhub_url.present?

          Base64.encode64({ 'credhub-uri' => credhub_url }.to_json)
        end
      end
    end
  end
end
