require 'diego/action_builder'
require 'cloud_controller/diego/task_environment_variable_collector'
require 'credhub/config_helpers'

module VCAP::CloudController
  module Diego
    module Buildpack
      class TaskActionBuilder
        include ::Diego::ActionBuilder
        class InvalidStack < StandardError; end

        def initialize(config, task, lifecycle_data, run_user, launcher_args, prefix)
          @config = config
          @task = task
          @lifecycle_data = lifecycle_data
          @run_user = run_user
          @launcher_args = launcher_args
          @prefix = prefix
        end

        def action
          download_droplet_action = ::Diego::Bbs::Models::DownloadAction.new(
            from: lifecycle_data[:droplet_uri],
            to: '.',
            cache_key: '',
            user: 'vcap'
          )
          if task.droplet.sha256_checksum
            download_droplet_action.checksum_algorithm = 'sha256'
            download_droplet_action.checksum_value = task.droplet.sha256_checksum
          else
            download_droplet_action.checksum_algorithm = 'sha1'
            download_droplet_action.checksum_value = task.droplet.droplet_hash
          end

          # launcher_args = ['app', task.command, '']

          run_action = ::Diego::Bbs::Models::RunAction.new(
            user: @run_user,
            path: '/tmp/lifecycle/launcher',
            args: @launcher_args,
            log_source: "APP/TASK/#{task.name}",
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
            env: task_environment_variables
          )

          if @config.get(:diego, :enable_declarative_asset_downloads) && task.droplet.sha256_checksum
            ::Diego::ActionBuilder.action(run_action)
          else
            serial([
              download_droplet_action,
              run_action
            ])
          end
        end

        def image_layers
          return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

          destination = @config.get(:diego, :droplet_destinations)[lifecycle_stack.to_sym]
          raise InvalidStack.new("no droplet destination defined for requested stack '#{lifecycle_stack}'") unless destination

          layers = [
            ::Diego::Bbs::Models::ImageLayer.new(
              name: "buildpack-#{lifecycle_stack}-lifecycle",
              url: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              destination_path: '/tmp/lifecycle',
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
            )
          ]

          if task.droplet.sha256_checksum
            layers << ::Diego::Bbs::Models::ImageLayer.new(
              name: 'droplet',
              url: lifecycle_data[:droplet_uri],
              destination_path: destination,
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
              digest_value: task.droplet.sha256_checksum,
              digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256
            )
          end

          layers
        end

        def task_environment_variables
          TaskEnvironmentVariableCollector.for_task task
        end

        def stack
          # Handle custom stacks (docker:// URLs)
          if lifecycle_stack.is_a?(String) && is_custom_stack?(lifecycle_stack)
            return normalize_stack_url(lifecycle_stack)
          end

          @stack ||= Stack.find(name: lifecycle_stack)
          raise CloudController::Errors::ApiError.new_from_details('StackNotFound', lifecycle_stack) unless @stack

          "preloaded:#{@stack.run_rootfs_image}"
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
            to: '/tmp/lifecycle',
            cache_key: "#{@prefix}-#{lifecycle_stack}-lifecycle"
          )]
        end

        def lifecycle_bundle_key
          :"#{@prefix}/#{lifecycle_stack}"
        end

        private

        attr_reader :task, :lifecycle_data, :config

        def lifecycle_stack
          lifecycle_data[:stack]
        end

        def is_custom_stack?(stack_name)
          # Check for various container registry URL formats
          return true if stack_name.include?('docker://')
          return true if stack_name.match?(%r{^https?://})  # Any https/http URL
          return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
          false
        end

        def normalize_stack_url(stack_url)
          return stack_url if stack_url.start_with?('docker://')
          return stack_url.sub(%r{^https?://}, 'docker://') if stack_url.match?(%r{^https?://})
          return "docker://#{stack_url}" if stack_url.include?('.')
          stack_url
        end
      end
    end
  end
end
