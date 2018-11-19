module VCAP::CloudController
  module Diego
    module Docker
      class DesiredLrpBuilder
        include ::Credhub::ConfigHelpers
        attr_reader :start_command

        def initialize(config, opts)
          @config = config
          @docker_image = opts[:docker_image]
          @execution_metadata = opts[:execution_metadata]
          @ports = opts[:ports]
          @start_command = opts[:start_command]
        end

        def cached_dependencies
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(@config.get(:diego, :lifecycle_bundles)[:docker]),
            to: '/tmp/lifecycle',
            cache_key: 'docker-lifecycle',
          )]
        end

        def root_fs
          DockerURIConverter.new.convert(@docker_image)
        end

        def setup
          nil
        end

        def global_environment_variables
          []
        end

        def ports
          if !@ports.empty?
            return @ports
          end

          execution_metadata = MultiJson.load(@execution_metadata)
          if execution_metadata['ports'].blank?
            return [DEFAULT_APP_PORT]
          end

          tcp_ports = execution_metadata['ports'].select { |port| port['protocol'] == 'tcp' }
          raise CloudController::Errors::ApiError.new_from_details('RunnerError', 'No tcp ports found in image metadata') if tcp_ports.empty?

          tcp_ports.map { |port| port['port'].to_i }
        end

        def port_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: ports.first.to_s),
          ]
        end

        def platform_options
          arr = []
          if credhub_url.present? && cred_interpolation_enabled?
            arr << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: credhub_url)
          end

          arr
        end

        def privileged?
          false
        end

        def action_user
          execution_metadata = MultiJson.load(@execution_metadata)
          user = execution_metadata['user']
          if user.nil? || user.empty?
            'root'
          else
            user
          end
        end
      end
    end
  end
end
