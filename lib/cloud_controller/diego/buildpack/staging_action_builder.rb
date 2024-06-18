require 'credhub/config_helpers'
require 'diego/action_builder'
require 'digest/xxhash'
require 'cloud_controller/diego/staging_action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingActionBuilder < VCAP::CloudController::Diego::StagingActionBuilder
        def initialize(config, staging_details, lifecycle_data)
          super(config, staging_details, lifecycle_data, 'buildpack', '/tmp/app', '/tmp/output-cache')
        end

        def additional_image_layers
          lifecycle_data[:buildpacks].
            reject { |buildpack| buildpack[:name] == 'custom' }.
            map do |buildpack|
            layer = {
              name: buildpack[:name],
              url: buildpack[:url],
              destination_path: buildpack_path(buildpack[:key]),
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP
            }
            if buildpack[:sha256]
              layer[:digest_algorithm] = ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256
              layer[:digest_value] = buildpack[:sha256]
            end

            ::Diego::Bbs::Models::ImageLayer.new(layer.compact)
          end
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          dependencies = [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{lifecycle_stack}-lifecycle"
            )
          ]

          others = lifecycle_data[:buildpacks].map do |buildpack|
            next if buildpack[:name] == 'custom'

            buildpack_dependency = {
              name: buildpack[:name],
              from: buildpack[:url],
              to: buildpack_path(buildpack[:key]),
              cache_key: buildpack[:key]
            }
            if buildpack[:sha256]
              buildpack_dependency[:checksum_algorithm] = 'sha256'
              buildpack_dependency[:checksum_value] = buildpack[:sha256]
            end

            ::Diego::Bbs::Models::CachedDependency.new(buildpack_dependency.compact)
          end.compact

          dependencies.concat(others)
        end

        def task_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: STAGING_DEFAULT_LANG)]
        end

        private

        def stage_action
          staging_details_env = BbsEnvironmentBuilder.build(staging_details.environment_variables)

          ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: [
              "-buildpackOrder=#{lifecycle_data[:buildpacks].pluck(:key).join(',')}",
              "-skipCertVerify=#{config.get(:skip_cert_verify)}",
              "-skipDetect=#{skip_detect?}",
              '-buildDir=/tmp/app',
              '-outputDroplet=/tmp/droplet',
              '-outputMetadata=/tmp/result.json',
              '-outputBuildArtifactsCache=/tmp/output-cache',
              '-buildpacksDir=/tmp/buildpacks',
              '-buildArtifactsCacheDir=/tmp/cache'
            ],
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config.get(:staging, :minimum_staging_file_descriptor_limit)),
            env: staging_details_env + platform_options_env
          )
        end

        def platform_options_env
          arr = []
          arr << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: credhub_url) if credhub_url.present? && cred_interpolation_enabled?

          arr
        end

        def buildpack_path(buildpack_key)
          if config.get(:staging, :legacy_md5_buildpack_paths_enabled)
            "/tmp/buildpacks/#{OpenSSL::Digest::MD5.hexdigest(buildpack_key)}"
          else
            "/tmp/buildpacks/#{Digest::XXH64.hexdigest(buildpack_key)}"
          end
        end
      end
    end
  end
end
