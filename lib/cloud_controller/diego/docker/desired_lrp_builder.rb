module VCAP::CloudController
  module Diego
    module Docker
      class DesiredLrpBuilder
        def initialize(config, app_request)
          @config = config
          @app_request = app_request
        end

        def cached_dependencies
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(@config[:diego][:lifecycle_bundles][:docker]),
            to: '/tmp/lifecycle',
            cache_key: 'docker-lifecycle',
          )]
        end

        def root_fs
          DockerURIConverter.new.convert(@app_request['docker_image'])
        end

        def setup
          nil
        end

        def global_environment_variables
          []
        end

        def ports
          if @app_request['ports'].length > 0
            return @app_request['ports']
          end
          execution_metadata = MultiJson.load(@app_request['execution_metadata'])
          if execution_metadata['ports'].empty?
            return [DEFAULT_APP_PORT]
          end
          tcp_ports = execution_metadata['ports'].select { |port| port['protocol'] == 'tcp' }
          fail AppRecipeBuilder::MissingAppPort if tcp_ports.empty?

          tcp_ports.map { |port| port['port'].to_i }
        end

        def privileged?
          false
        end

        def action_user
          execution_metadata = MultiJson.load(@app_request['execution_metadata'])
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
