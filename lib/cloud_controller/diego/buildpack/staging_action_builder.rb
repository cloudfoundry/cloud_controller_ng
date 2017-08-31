module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingActionBuilder
        include ::Diego::ActionBuilder

        attr_reader :config, :lifecycle_data, :staging_details

        def initialize(config, staging_details, lifecycle_data)
          @config          = config
          @lifecycle_data  = lifecycle_data
          @staging_details = staging_details
        end

        def action
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
              from:      LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              to:        '/tmp/lifecycle',
              cache_key: "buildpack-#{stack}-lifecycle",
            )
          ]

          dependencies.concat(
            lifecycle_data[:buildpacks].map do |buildpack|
              next if buildpack[:name] == 'custom'

              buildpack_dependency = {
                name:               buildpack[:name],
                from:               buildpack[:url],
                to:                 "/tmp/buildpacks/#{Digest::MD5.hexdigest(buildpack[:key])}",
                cache_key:          buildpack[:key],
              }
              if buildpack[:sha256]
                buildpack_dependency[:checksum_algorithm] = 'sha256'
                buildpack_dependency[:checksum_value] = buildpack[:sha256]
              end

              ::Diego::Bbs::Models::CachedDependency.new(buildpack_dependency)
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

        def download_actions
          result = [
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact:           'app package',
              from:               lifecycle_data[:app_bits_download_uri],
              to:                 '/tmp/app',
              user:               'vcap',
              checksum_algorithm: lifecycle_data[:app_bits_checksum][:type],
              checksum_value:     lifecycle_data[:app_bits_checksum][:value],
            )
          ]
          if lifecycle_data[:build_artifacts_cache_download_uri] && lifecycle_data[:buildpack_cache_checksum].present?
            result << try_action(::Diego::Bbs::Models::DownloadAction.new({
              artifact:           'build artifacts cache',
              from:               lifecycle_data[:build_artifacts_cache_download_uri],
              to:                 '/tmp/cache',
              user:               'vcap',
              checksum_algorithm: 'sha256',
              checksum_value:     lifecycle_data[:buildpack_cache_checksum],
            }))
          end

          result
        end

        def stage_action
          ::Diego::Bbs::Models::RunAction.new(
            path:            '/tmp/lifecycle/builder',
            user:            'vcap',
            args:            [
              "-buildpackOrder=#{lifecycle_data[:buildpacks].map { |i| i[:key] }.join(',')}",
              "-skipCertVerify=#{config.get(:skip_cert_verify)}",
              "-skipDetect=#{skip_detect?}",
              '-buildDir=/tmp/app',
              '-outputDroplet=/tmp/droplet',
              '-outputMetadata=/tmp/result.json',
              '-outputBuildArtifactsCache=/tmp/output-cache',
              '-buildpacksDir=/tmp/buildpacks',
              '-buildArtifactsCacheDir=/tmp/cache',
            ],
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config.get(:staging, :minimum_staging_file_descriptor_limit)),
            env:             BbsEnvironmentBuilder.build(staging_details.environment_variables)
          )
        end

        def upload_actions
          [
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
        end

        def skip_detect?
          lifecycle_data[:buildpacks].any? { |buildpack| buildpack[:skip_detect] }
        end

        def lifecycle_bundle_key
          "buildpack/#{lifecycle_data[:stack]}".to_sym
        end

        def upload_buildpack_artifacts_cache_uri
          upload_buildpack_artifacts_cache_uri       = URI(config.get(:diego, :cc_uploader_url))
          upload_buildpack_artifacts_cache_uri.path  = "/v1/build_artifacts/#{staging_details.staging_guid}"
          upload_buildpack_artifacts_cache_uri.query = {
            'cc-build-artifacts-upload-uri' => lifecycle_data[:build_artifacts_cache_upload_uri],
            'timeout'                       => config.get(:staging, :timeout_in_seconds),
          }.to_param
          upload_buildpack_artifacts_cache_uri.to_s
        end

        def upload_droplet_uri
          upload_droplet_uri       = URI(config.get(:diego, :cc_uploader_url))
          upload_droplet_uri.path  = "/v1/droplet/#{staging_details.staging_guid}"
          upload_droplet_uri.query = {
            'cc-droplet-upload-uri' => lifecycle_data[:droplet_upload_uri],
            'timeout'               => config.get(:staging, :timeout_in_seconds),
          }.to_param
          upload_droplet_uri.to_s
        end
      end
    end
  end
end
