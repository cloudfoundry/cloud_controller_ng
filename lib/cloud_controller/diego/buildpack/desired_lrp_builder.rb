module VCAP::CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        include ::Diego::ActionBuilder

        attr_reader :start_command

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
        end

        def cached_dependencies
          lifecycle_bundle_key = "buildpack/#{@stack}".to_sym
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(@config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{@stack}-lifecycle"
            )
          ]
        end

        def root_fs
          if @config[:diego][:temporary_oci_buildpack_mode] == 'oci-phase-1'
            "preloaded+layer:#{@stack}?layer=#{URI.encode(@droplet_uri)}"
          else
            "preloaded:#{@stack}"
          end
        end

        def setup
          return nil if @config[:diego][:temporary_oci_buildpack_mode] == 'oci-phase-1'

          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: @droplet_uri,
              to: '.',
              cache_key: "droplets-#{@process_guid}",
              user: 'vcap',
              checksum_algorithm: @checksum_algorithm,
              checksum_value: @checksum_value,
            )
          ])
        end

        def global_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)]
        end

        def ports
          @ports || [DEFAULT_APP_PORT]
        end

        def port_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_HOST', value: '0.0.0.0'),
          ]
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
