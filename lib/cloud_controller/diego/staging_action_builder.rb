require 'credhub/config_helpers'
require 'diego/action_builder'
require 'digest/xxhash'

module VCAP::CloudController
  module Diego
    class StagingActionBuilder
      include ::Credhub::ConfigHelpers
      include ::Diego::ActionBuilder

      attr_reader :config, :lifecycle_data, :staging_details

      def initialize(config, staging_details, lifecycle_data, prefix, app_destination_path, cache_source, bp_media_type)
        @config          = config
        @staging_details = staging_details
        @lifecycle_data  = lifecycle_data
        @prefix = prefix
        @app_destination_path = app_destination_path
        @cache_source = cache_source
        @bp_media_type = bp_media_type
      end

      def action
        actions = [
          stage_action,
          emit_progress(
            parallel(upload_actions),
            start_message: 'Uploading droplet, build artifacts cache...',
            success_message: 'Uploading complete',
            failure_message_prefix: 'Uploading failed'
          )
        ]

        actions.prepend(parallel(download_actions)) unless download_actions.empty?

        serial(actions)
      end

      def cached_dependencies
        return nil if @config.get(:diego, :enable_declarative_asset_downloads)

        # For custom stacks, use a default lifecycle bundle since they won't be in config
        bundle_key = lifecycle_bundle_key
        lifecycle_bundle = config.get(:diego, :lifecycle_bundles)[bundle_key]

        # If custom stack doesn't have a bundle, use the default stack's bundle
        if !lifecycle_bundle && lifecycle_stack.is_a?(String) && is_custom_stack?(lifecycle_stack)
          default_stack = Stack.default.name
          bundle_key = :"#{@prefix}/#{default_stack}"
          lifecycle_bundle = config.get(:diego, :lifecycle_bundles)[bundle_key]
        end

        dependencies = [
          ::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(lifecycle_bundle),
            to: '/tmp/lifecycle',
            cache_key: "#{@prefix}-#{normalize_stack_for_cache_key(lifecycle_stack)}-lifecycle"
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

      def additional_image_layers
        lifecycle_data[:buildpacks].
          reject { |buildpack| buildpack[:name] == 'custom' }.
          map do |buildpack|
          layer = {
            name: buildpack[:name],
            url: buildpack[:url],
            destination_path: buildpack_path(buildpack[:key]),
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
            media_type: @bp_media_type
          }
          if buildpack[:sha256]
            layer[:digest_algorithm] = ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256
            layer[:digest_value] = buildpack[:sha256]
          end

          ::Diego::Bbs::Models::ImageLayer.new(layer.compact)
        end
      end

      def image_layers
        return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

        # For custom stacks, use a default lifecycle bundle since they won't be in config
        bundle_key = lifecycle_bundle_key
        lifecycle_bundle = config.get(:diego, :lifecycle_bundles)[bundle_key]

        # If custom stack doesn't have a bundle, use the default stack's bundle
        if !lifecycle_bundle && lifecycle_stack.is_a?(String) && is_custom_stack?(lifecycle_stack)
          default_stack = Stack.default.name
          bundle_key = :"#{@prefix}/#{default_stack}"
          lifecycle_bundle = config.get(:diego, :lifecycle_bundles)[bundle_key]
        end

        layers = [
          ::Diego::Bbs::Models::ImageLayer.new(
            name: "#{@prefix}-#{lifecycle_stack}-lifecycle",
            url: LifecycleBundleUriGenerator.uri(lifecycle_bundle),
            destination_path: '/tmp/lifecycle',
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
            media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
          )
        ]

        if lifecycle_data[:app_bits_checksum][:type] == 'sha256'
          layers << ::Diego::Bbs::Models::ImageLayer.new({
            name: 'app package',
            url: lifecycle_data[:app_bits_download_uri],
            destination_path: @app_destination_path,
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
            media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
            digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
            digest_value: lifecycle_data[:app_bits_checksum][:value]
          }.compact)
        end

        if lifecycle_data[:build_artifacts_cache_download_uri] && lifecycle_data[:buildpack_cache_checksum].present?
          layers << ::Diego::Bbs::Models::ImageLayer.new({
            name: 'build artifacts cache',
            url: lifecycle_data[:build_artifacts_cache_download_uri],
            destination_path: '/tmp/cache',
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
            media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
            digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
            digest_value: lifecycle_data[:buildpack_cache_checksum]
          }.compact)
        end

        buildpack_layers = additional_image_layers

        layers.concat(buildpack_layers)
      end

      def stack
        # Handle custom stacks (docker:// URLs)
        if lifecycle_stack.is_a?(String) && is_custom_stack?(lifecycle_stack)
          return normalize_stack_url(lifecycle_stack)
        end

        @stack ||= Stack.find(name: lifecycle_stack)
        raise CloudController::Errors::ApiError.new_from_details('StackNotFound', lifecycle_stack) unless @stack

        "preloaded:#{@stack.build_rootfs_image}"
      end

      def lifecycle_stack
        lifecycle_data[:stack]
      end

      private

      def download_actions
        result = []

        unless @config.get(:diego, :enable_declarative_asset_downloads) && lifecycle_data[:app_bits_checksum][:type] == 'sha256'
          result << ::Diego::Bbs::Models::DownloadAction.new({
            artifact: 'app package',
            from: lifecycle_data[:app_bits_download_uri],
            to: @app_destination_path,
            user: 'vcap',
            checksum_algorithm: lifecycle_data[:app_bits_checksum][:type],
            checksum_value: lifecycle_data[:app_bits_checksum][:value]
          }.compact)
        end

        if !@config.get(:diego,
                        :enable_declarative_asset_downloads) && lifecycle_data[:build_artifacts_cache_download_uri] && lifecycle_data[:buildpack_cache_checksum].present?
          result << try_action(::Diego::Bbs::Models::DownloadAction.new({
            artifact: 'build artifacts cache',
            from: lifecycle_data[:build_artifacts_cache_download_uri],
            to: '/tmp/cache',
            user: 'vcap',
            checksum_algorithm: 'sha256',
            checksum_value: lifecycle_data[:buildpack_cache_checksum]
          }.compact))
        end

        result
      end

      def upload_actions
        [
          ::Diego::Bbs::Models::UploadAction.new(
            user: 'vcap',
            artifact: 'droplet',
            from: '/tmp/droplet',
            to: upload_droplet_uri.to_s
          ),

          ::Diego::Bbs::Models::UploadAction.new(
            user: 'vcap',
            artifact: 'build artifacts cache',
            from: @cache_source,
            to: upload_buildpack_artifacts_cache_uri.to_s
          )
        ]
      end

      def skip_detect?
        lifecycle_data[:buildpacks].any? { |buildpack| buildpack[:skip_detect] }
      end

      def lifecycle_bundle_key
        :"#{@prefix}/#{lifecycle_data[:stack]}"
      end

      def upload_buildpack_artifacts_cache_uri
        upload_buildpack_artifacts_cache_uri       = URI(config.get(:diego, :cc_uploader_url))
        upload_buildpack_artifacts_cache_uri.path  = "/v1/build_artifacts/#{staging_details.staging_guid}"
        upload_buildpack_artifacts_cache_uri.query = {
          'cc-build-artifacts-upload-uri' => lifecycle_data[:build_artifacts_cache_upload_uri],
          'timeout' => config.get(:staging, :timeout_in_seconds)
        }.to_param
        upload_buildpack_artifacts_cache_uri.to_s
      end

      def upload_droplet_uri
        upload_droplet_uri       = URI(config.get(:diego, :cc_uploader_url))
        upload_droplet_uri.path  = "/v1/droplet/#{staging_details.staging_guid}"
        upload_droplet_uri.query = {
          'cc-droplet-upload-uri' => lifecycle_data[:droplet_upload_uri],
          'timeout' => config.get(:staging, :timeout_in_seconds)
        }.to_param
        upload_droplet_uri.to_s
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

      def normalize_stack_for_cache_key(stack_name)
        return stack_name unless stack_name.is_a?(String) && is_custom_stack?(stack_name)

        # Extract the image name from the Docker URL for cache key compatibility
        # Examples:
        # https://docker.io/cloudfoundry/cflinuxfs4 -> cflinuxfs4
        # docker://cloudfoundry/cflinuxfs3 -> cflinuxfs3
        # docker.io/cloudfoundry/cflinuxfs4 -> cflinuxfs4
        normalized_url = stack_name.gsub(%r{^(https?://|docker://)}, '')
        if normalized_url.include?('/')
          # Extract the last part of the path
          parts = normalized_url.split('/')
          parts.last
        else
          # If no path, use as-is
          normalized_url
        end
      end

      def is_custom_stack?(stack_name)
        # Check for various container registry URL formats
        return true if stack_name.include?('docker://')
        return true if stack_name.match?(%r{^https?://})  # Any https/http URL
        return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
        false
      end

      def normalize_stack_url(stack_url)
        return stack_url if stack_url.start_with?('docker://')
        return stack_url.sub(%r{^https?://}, 'docker://') if stack_url.match?(%r{^https?://})
        return "docker://#{stack_url}" if stack_url.include?('.')
        stack_url
      end
    end
  end
end
