module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingActionBuilder
        include ::Diego::ActionBuilder

        attr_reader :config, :lifecycle_data, :staging_details, :env

        def initialize(config, lifecycle_data, staging_details, env)
          @config          = config
          @lifecycle_data  = lifecycle_data
          @staging_details = staging_details
          @env             = env
        end

        def action
          download_actions = [
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'app package',
              from:     lifecycle_data[:app_bits_download_uri],
              to:       '/tmp/app',
              user:     'vcap'
            )
          ]
          if lifecycle_data[:build_artifacts_cache_download_uri]
            download_actions << ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'build artifacts cache',
              from:     lifecycle_data[:build_artifacts_cache_download_uri],
              to:       '/tmp/cache',
              user:     'vcap'
            )
          end

          stage_action = ::Diego::Bbs::Models::RunAction.new(
            path:            '/tmp/lifecycle/builder',
            user:            'vcap',
            args:            [
              "-buildpackOrder=#{lifecycle_data[:buildpacks].map { |i| i[:key] }.join(',')}",
              "-skipCertVerify=#{config[:skip_cert_verify]}",
              "-skipDetect=#{!!lifecycle_data[:buildpacks].first[:skip_detect]}",
            ],
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config[:staging][:minimum_staging_file_descriptor_limit]),
            env:             env
          )

          upload_actions = [
            ::Diego::Bbs::Models::UploadAction.new(
              user:     'vcap',
              artifact: 'droplet',
              from:     '/tmp/droplet',
              to:       upload_droplet_uri.to_s,
            ),

            ::Diego::Bbs::Models::UploadAction.new(
              user:     'vcap',
              artifact: 'build artifacts cache',
              from:     '/tmp/output-cache',
              to:       upload_buildpack_artifacts_cache_uri.to_s,
            )
          ]

          serial([
            parallel(download_actions),
            stage_action,
            emit_progress(
              parallel(upload_actions),
              start_message:          'Uploading droplet, build artifacts cache...',
              success_message:        'Uploading complete',
              failure_message_prefix: 'Uploading failed'
            )
          ])
        end

        def cached_dependencies
          dependencies = [
            ::Diego::Bbs::Models::CachedDependency.new(
              from:      lifecycle_cached_dependency_uri,
              to:        '/tmp/lifecycle',
              cache_key: "buildpack-#{stack}-lifecycle",
            )
          ]

          dependencies.concat(
            lifecycle_data[:buildpacks].map do |buildpack|
              next if buildpack[:name] == 'custom'

              ::Diego::Bbs::Models::CachedDependency.new(
                name:      buildpack[:name],
                from:      buildpack[:url],
                to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest(buildpack[:key])}",
                cache_key: buildpack[:key],
              )
            end.compact
          )
        end

        def stack
          lifecycle_data[:stack]
        end

        def task_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: STAGING_DEFAULT_LANG)]
        end

        private

        def lifecycle_cached_dependency_uri
          lifecycle_bundle = config[:diego][:lifecycle_bundles]["buildpack/#{stack}".to_sym]

          raise CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed: no compiler defined for requested stack') unless lifecycle_bundle

          lifecycle_bundle_url = URI(lifecycle_bundle)

          case lifecycle_bundle_url.scheme
          when 'http', 'https'
            lifecycle_cached_dependency_uri = lifecycle_bundle_url
          when nil
            lifecycle_cached_dependency_uri = URI(config[:diego][:file_server_url])
            lifecycle_cached_dependency_uri.path = "/v1/static/#{lifecycle_bundle}"
          else
            raise CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed: invalid compiler URI')
          end
          lifecycle_cached_dependency_uri.to_s
        end

        def upload_buildpack_artifacts_cache_uri
          upload_buildpack_artifacts_cache_uri       = URI(config[:diego][:cc_uploader_url])
          upload_buildpack_artifacts_cache_uri.path  = "/v1/build_artifacts/#{staging_details.droplet.guid}"
          upload_buildpack_artifacts_cache_uri.query = {
            'cc-build-artifacts-upload-uri' => lifecycle_data[:build_artifacts_cache_upload_uri],
            'timeout'                       => config[:staging][:timeout_in_seconds],
          }.to_param
          upload_buildpack_artifacts_cache_uri.to_s
        end

        def upload_droplet_uri
          upload_droplet_uri       = URI(config[:diego][:cc_uploader_url])
          upload_droplet_uri.path  = "/v1/droplet/#{staging_details.droplet.guid}"
          upload_droplet_uri.query = {
            'cc-droplet-upload-uri' => lifecycle_data[:droplet_upload_uri],
            'timeout'               => config[:staging][:timeout_in_seconds],
          }.to_param
          upload_droplet_uri.to_s
        end
      end
    end
  end
end
