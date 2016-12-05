module VCAP::CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        include ::Diego::ActionBuilder

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

        def setup
          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: @app_request['droplet_uri'],
              to: '.',
              cache_key: "droplets-#{@app_request['process_guid']}",
              user: 'vcap',
              checksum_algorithm: 'sha1',
              checksum_value: @app_request['droplet_hash'],
            )
          ])
        end

        def global_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)]
        end

        def ports
          @app_request['ports'] || [DEFAULT_APP_PORT]
        end

        def privileged?
          @config[:diego][:use_privileged_containers_for_running]
        end

        def action_user
          'vcap'
        end
      end
    end
  end
end
