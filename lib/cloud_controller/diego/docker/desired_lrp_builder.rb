module VCAP::CloudController
  module Diego
    module Docker
      class DesiredLrpBuilder
        attr_reader :start_command, :action_user

        def initialize(config, opts)
          @config = config
          @docker_image = opts[:docker_image]
          @execution_metadata = opts[:execution_metadata]
          @ports = opts[:ports]
          @start_command = opts[:start_command]
          @action_user = opts[:action_user]
          @additional_container_env_vars = opts[:additional_container_env_vars]
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(@config.get(:diego, :lifecycle_bundles)[:docker]),
            to: '/tmp/lifecycle',
            cache_key: 'docker-lifecycle'
          )]
        end

        def root_fs
          DockerURIConverter.new.convert(@docker_image)
        end

        def setup
          nil
        end

        def image_layers
          return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

          [::Diego::Bbs::Models::ImageLayer.new(
            name: 'docker-lifecycle',
            url: LifecycleBundleUriGenerator.uri(@config.get(:diego, :lifecycle_bundles)[:docker]),
            destination_path: '/tmp/lifecycle',
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
            media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
          )]
        end

        def global_environment_variables
          [] + @additional_container_env_vars
        end

        def ports
          return @ports unless @ports.empty?

          execution_metadata = Oj.load(@execution_metadata)
          return [DEFAULT_APP_PORT] if execution_metadata['ports'].blank?

          tcp_ports = execution_metadata['ports'].select { |port| port['protocol'] == 'tcp' }
          raise CloudController::Errors::ApiError.new_from_details('RunnerError', 'No tcp ports found in image metadata') if tcp_ports.empty?

          tcp_ports.map { |port| port['port'].to_i }
        end

        def port_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: ports.first.to_s)
          ]
        end

        def privileged?
          false
        end
      end
    end
  end
end
