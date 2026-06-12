require 'cloud_controller/diego/custom_stack_uri_converter'
require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        include ::Diego::ActionBuilder

        class InvalidStack < StandardError; end

        attr_reader :start_command, :action_user

        def initialize(config, opts)
          @config = config
          @stack = opts[:stack]
          @droplet_uri = opts[:droplet_uri]
          @process_guid = opts[:process_guid]
          @droplet_hash = opts[:droplet_hash]
          @ports = opts[:ports]
          @checksum_algorithm = opts[:checksum_algorithm]
          @checksum_value = opts[:checksum_value]
          @start_command = opts[:start_command]
          @action_user = opts[:action_user]
          @additional_container_env_vars = opts[:additional_container_env_vars]
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          lifecycle_bundle_key = resolved_lifecycle_bundle_key
          lifecycle_bundle = @config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]
          raise InvalidStack.new("no compiler defined for requested stack '#{@stack}'") unless lifecycle_bundle

          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(lifecycle_bundle),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{resolved_stack_name}-lifecycle"
            )
          ]
        end

        def root_fs
          return CustomStackUriConverter.new.convert(@stack) if UriUtils.is_custom_stack_uri?(@stack)

          @stack_obj ||= Stack.find(name: @stack)
          raise CloudController::Errors::ApiError.new_from_details('StackNotFound', @stack) unless @stack_obj

          "preloaded:#{@stack_obj.run_rootfs_image}"
        end

        def setup
          return nil if @config.get(:diego, :enable_declarative_asset_downloads) && @checksum_algorithm == 'sha256'

          serial([
            ::Diego::Bbs::Models::DownloadAction.new({
              artifact: 'droplet',
              from: @droplet_uri,
              to: '.',
              cache_key: "droplets-#{@process_guid}",
              user: action_user,
              checksum_algorithm: @checksum_algorithm,
              checksum_value: @checksum_value
            }.compact)
          ])
        end

        def image_layers
          return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

          lifecycle_bundle_key = resolved_lifecycle_bundle_key
          lifecycle_bundle = @config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]
          raise InvalidStack.new("no compiler defined for requested stack '#{@stack}'") unless lifecycle_bundle

          destination = @config.get(:diego, :droplet_destinations)[resolved_stack_name.to_sym]
          raise InvalidStack.new("no droplet destination defined for requested stack '#{@stack}'") unless destination

          layers = [
            ::Diego::Bbs::Models::ImageLayer.new(
              name: "buildpack-#{resolved_stack_name}-lifecycle",
              url: LifecycleBundleUriGenerator.uri(lifecycle_bundle),
              destination_path: '/tmp/lifecycle',
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
            )
          ]

          if @checksum_algorithm == 'sha256'
            layers << ::Diego::Bbs::Models::ImageLayer.new({
              name: 'droplet',
              url: UriUtils.uri_escape(@droplet_uri),
              destination_path: destination,
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
              digest_value: @checksum_value,
              digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256
            }.compact)
          end

          layers
        end

        def global_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)] + @additional_container_env_vars
        end

        def ports
          return @ports if @ports.present?

          [DEFAULT_APP_PORT]
        end

        def port_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_HOST', value: '0.0.0.0')
          ]
        end

        def privileged?
          @config.get(:diego, :use_privileged_containers_for_running)
        end

        private

        # For custom stacks, fall back to the default stack for lifecycle bundle and droplet destination lookups
        def resolved_stack_name
          if UriUtils.is_custom_stack_uri?(@stack)
            VCAP::CloudController::Stack.default.name
          else
            @stack
          end
        end

        def resolved_lifecycle_bundle_key
          :"buildpack/#{resolved_stack_name}"
        end
      end
    end
  end
end
