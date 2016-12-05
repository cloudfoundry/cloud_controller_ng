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
      end
    end
  end
end
