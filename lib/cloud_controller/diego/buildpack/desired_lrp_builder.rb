module VCAP::CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        def initialize(config, app_request)
          @config = config
          @app_request = app_request
        end

        def cached_dependencies
          lifecycle_bundle_key = "buildpack/#{@app_request['stack']}".to_sym
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(@config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{@app_request['stack']}-lifecycle"
            )
          ]
        end

        def root_fs
          "preloaded:#{@app_request['stack']}"
        end
      end
    end
  end
end
