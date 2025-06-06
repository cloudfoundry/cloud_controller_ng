require 'open3'
require 'tempfile'
require 'fileutils'
require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/cli/azure_blob'

module CloudController
  module Blobstore
    # POC: This client uses the `azure-storage-cli` tool from bosh to interact with Azure Blob Storage.
    # It is a proof of concept and not intended for production use.
    # Goal of this POC is to find out if the bosh blobstore CLIs can be used as a replacement for the fog.

    class AzureCliClient < BaseClient
      attr_reader :root_dir, :min_size, :max_size

      def initialize(fog_connection:, directory_key:, root_dir:, min_size: nil, max_size: nil)
        @cli_path = ENV['AZURE_STORAGE_CLI_PATH'] || '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli'
        @directory_key = directory_key
        @root_dir = root_dir
        @min_size = min_size
        @max_size = max_size

        config = {
          'account_name' => fog_connection[:azure_storage_account_name],
          'account_key' => fog_connection[:azure_storage_access_key],
          'container_name' => @directory_key,
          'environment' => fog_connection[:environment]

        }.compact

        @config_file = write_config_file(config, fog_connection[:container_name])
      end

      def cp_to_blobstore(source_path, destination_key)
        logger.info("[azure-blobstore] cp_to_blobstore: uploading #{source_path} → #{destination_key}")
        run_cli('put', source_path, partitioned_key(destination_key))
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def download_from_blobstore(source_key, destination_path, mode: nil)
        # rubocop:enable Lint/UnusedMethodArgument
        logger.info("[azure-blobstore] download_from_blobstore: downloading #{source_key} → #{destination_path}")
        FileUtils.mkdir_p(File.dirname(destination_path))
        run_cli('get', partitioned_key(source_key), destination_path)

        # POC: Writing chunks to file is not implemented yet
        # POC: mode is not used for now
      end

      def exists?(blobstore_key)
        key = partitioned_key(blobstore_key)
        logger.info("[azure-blobstore] [exists?] Checking existence for: #{key}")
        status = run_cli('exists', key, allow_nonzero: true)

        if status.exitstatus == 0
          return true
        elsif status.exitstatus == 3
          return false
        end

        false
      rescue StandardError => e
        logger.error("[azure-blobstore] [exists?] azure-storage-cli exists raised error: #{e.message} for #{key}")
        false
      end

      def delete_blob(blob)
        delete(blob.file.key)
      end

      def delete(key)
        logger.info("[azure-blobstore] delete: removing blob with key #{key}")
        run_cli('delete', partitioned_key(key))
      end

      # Methods like `delete_all` and `delete_all_in_path` are not implemented in this POC.

      def blob(key)
        logger.info("[azure-blobstore] blob: retrieving blob with key #{key}")

        return nil unless exists?(key)

        signed_url = sign_url(partitioned_key(key), verb: 'get', expires_in_seconds: 3600)
        AzureBlob.new(key, exists: true, signed_url: signed_url)
      end

      def sign_url(key, verb:, expires_in_seconds:)
        logger.info("[azure-blobstore] sign_url: signing URL for key #{key} with verb #{verb} and expires_in_seconds #{expires_in_seconds}")
        stdout, stderr, status = Open3.capture3(@cli_path, '-c', @config_file, 'sign', key, verb.to_s.downcase, "#{expires_in_seconds}s")
        raise "azure-storage-cli sign failed: #{stderr}" unless status.success?

        stdout.strip
      end

      def ensure_bucket_exists
        # POC - not sure if this is needed
      end

      def cp_file_between_keys(source_key, destination_key)
        logger.info("[azure-blobstore] cp_file_between_keys: copying from #{source_key} to #{destination_key}")
        # Azure CLI doesn't support server-side copy yet, so fallback to local copy
        # POC! We should copy directly in the cli if possible
        Tempfile.create('blob-copy') do |tmp|
          download_from_blobstore(source_key, tmp.path)
          cp_to_blobstore(tmp.path, destination_key)
        end
      end

      def local?
        false
      end

      private

      def run_cli(command, *args, allow_nonzero: false)
        logger.info("[azure-blobstore] Running azure-storage-cli: #{@cli_path} -c #{@config_file} #{command} #{args.join(' ')}")
        _, stderr, status = Open3.capture3(@cli_path, '-c', @config_file, command, *args)
        return status if allow_nonzero

        raise "azure-storage-cli #{command} failed: #{stderr}" unless status.success?

        status
      end

      def write_config_file(config, container_name)
        config_dir = File.join(tmpdir, 'blobstore-configs')
        FileUtils.mkdir_p(config_dir)

        config_file_path = File.join(config_dir, "blobstore-config-#{container_name}")
        File.open(config_file_path, 'w', 0o600) do |f|
          f.write(Oj.dump(config))
        end
        config_file_path
      end

      def tmpdir
        VCAP::CloudController::Config.config.get(:directories, :tmpdir)
      end

      def logger
        @logger ||= Steno.logger('cc.azure_cli_client')
      end
    end
  end
end
