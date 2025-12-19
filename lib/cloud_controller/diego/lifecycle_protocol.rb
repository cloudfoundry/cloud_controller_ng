require 'cloud_controller/diego/windows_environment_sage'

module VCAP::CloudController
  module Diego
    module LifecycleProtocol
      def self.protocol_for_type(lifecycle_type)
        case lifecycle_type
        when VCAP::CloudController::Lifecycles::BUILDPACK
          VCAP::CloudController::Diego::Buildpack::LifecycleProtocol.new
        when VCAP::CloudController::Lifecycles::DOCKER
          VCAP::CloudController::Diego::Docker::LifecycleProtocol.new
        when VCAP::CloudController::Lifecycles::CNB
          VCAP::CloudController::Diego::CNB::LifecycleProtocol.new
        end
      end
    end

    class LifecycleProtocolBase
      class InvalidDownloadUri < StandardError; end

      def initialize(blobstore_url_generator=::CloudController::DependencyLocator.instance.blobstore_url_generator,
                     droplet_url_generator=::CloudController::DependencyLocator.instance.droplet_url_generator)
        @blobstore_url_generator   = blobstore_url_generator
        @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator, type)
        @droplet_url_generator = droplet_url_generator
      end

      def lifecycle_data(staging_details)
        stack                                             = staging_details.lifecycle.staging_stack
        lifecycle_data                                    = new_lifecycle_data(staging_details)
        lifecycle_data.app_bits_download_uri              = @blobstore_url_generator.package_download_url(staging_details.package)
        lifecycle_data.app_bits_checksum                  = staging_details.package.checksum_info
        lifecycle_data.buildpack_cache_checksum           = staging_details.package.app.buildpack_cache_sha256_checksum
        lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.buildpack_cache_download_url(staging_details.package.app_guid, normalize_stack_for_cache_key(stack))
        lifecycle_data.build_artifacts_cache_upload_uri   = @blobstore_url_generator.buildpack_cache_upload_url(staging_details.package.app_guid, normalize_stack_for_cache_key(stack))
        lifecycle_data.droplet_upload_uri                 = @blobstore_url_generator.droplet_upload_url(staging_details.staging_guid)
        lifecycle_data.buildpacks                         = @buildpack_entry_generator.buildpack_entries(staging_details.lifecycle.buildpack_infos, stack)
        lifecycle_data.stack                              = stack

        lifecycle_data.message
      rescue Membrane::SchemaValidationError => e
        raise e unless e.message.match?(/app_bits_download_uri/)

        logger.error "app_bits_download_uri is nil for package #{staging_details.package.guid}"
        raise InvalidDownloadUri.new("Failed to get blobstore download url for package #{staging_details.package.guid}")
      end

      private

      def droplet_checksum_info(droplet)
        if droplet.sha256_checksum
          { 'type' => 'sha256', 'value' => droplet.sha256_checksum }
        else
          { 'type' => 'sha1', 'value' => droplet.droplet_hash }
        end
      end

      def builder_opts(process)
        checksum_info = droplet_checksum_info(process.actual_droplet)
        {
          droplet_uri: @droplet_url_generator.perma_droplet_download_url(process.guid, checksum_info['value']),
          droplet_hash: process.actual_droplet.droplet_hash,
          ports: process.open_ports,
          process_guid: ProcessGuid.from_process(process),
          stack: process.app.lifecycle_data.stack,
          checksum_algorithm: checksum_info['type'],
          checksum_value: checksum_info['value'],
          start_command: process.started_command,
          action_user: process.run_action_user,
          additional_container_env_vars: container_env_vars_for_process(process)
        }
      end

      def task_lifecycle_data(task)
        {
          droplet_uri: droplet_download_uri(task),
          stack: task.app.lifecycle_data.stack
        }
      end

      def droplet_download_uri(task)
        download_url = @blobstore_url_generator.droplet_download_url(task.droplet)
        raise InvalidDownloadUri.new("Failed to get blobstore download url for droplet #{task.droplet_guid}") unless download_url

        download_url
      end

      def container_env_vars_for_process(process)
        additional_env = []
        additional_env + WindowsEnvironmentSage.ponder(process.app)
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

      def logger
        @logger ||= Steno.logger('cc.diego.tr')
      end
    end
  end
end
