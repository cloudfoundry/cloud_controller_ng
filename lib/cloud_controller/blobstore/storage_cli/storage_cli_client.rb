require 'open3'
require 'tempfile'
require 'fileutils'
require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/cli/azure_blob'

module CloudController
  module Blobstore
    class StorageCliClient < BaseClient
      attr_reader :root_dir, :min_size, :max_size

      DEFAULT_BATCH_SIZE = 1000

      @registry = {}

      class << self
        def register(provider, klass)
          @registry[provider] = klass
        end

        def build(fog_connection:, directory_key:, root_dir:, min_size: nil, max_size: nil)
          provider = fog_connection[:provider]
          raise 'Missing fog_connection[:provider]' if provider.nil?

          impl_class = @registry[provider]
          raise "No CLI client registered for provider #{provider}" unless impl_class

          impl_class.new(fog_connection:, directory_key:, root_dir:, min_size:, max_size:)
        end
      end

      def initialize(fog_connection:, directory_key:, root_dir:, min_size: nil, max_size: nil)
        @cli_path = cli_path
        @directory_key = directory_key
        @root_dir = root_dir
        @min_size = min_size
        @max_size = max_size

        config = build_config(fog_connection)
        @config_file = write_config_file(config)
      end

      def local?
        false
      end

      def exists?(blobstore_key)
        key = partitioned_key(blobstore_key)
        _, status = run_cli('exists', key, allow_exit_code_three: true)

        if status.exitstatus == 0
          return true
        elsif status.exitstatus == 3
          return false
        end

        false
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))
        run_cli('get', partitioned_key(source_key), destination_path)

        File.chmod(mode, destination_path) if mode
      end

      def cp_to_blobstore(source_path, destination_key)
        start     = Time.now.utc
        log_entry = 'cp-skip'
        size      = -1

        logger.info('cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          run_cli('put', source_path, partitioned_key(destination_key))
          log_entry = 'cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: duration,
                    size: size)
      end

      def cp_file_between_keys(source_key, destination_key)
        # Azure CLI doesn't support server-side copy yet, so fallback to local copy
        # POC! We should copy directly in the cli if possible
        Tempfile.create('blob-copy') do |tmp|
          download_from_blobstore(source_key, tmp.path)
          cp_to_blobstore(tmp.path, destination_key)
        end
      end

      def delete_all(page_size: DEFAULT_BATCH_SIZE)
        # TODO: WIP!
        logger.info("Attempting to delete all files in #{@directory_key}/#{@root_dir} blobstore")
        # Currently, storage-cli does not support bulk deletion.
      end

      def delete_all_in_path(path)
        # TODO: WIP!
        # Currently, storage-cli does not support bulk deletion in a specific path.
      end

      def delete(key)
        run_cli('delete', partitioned_key(key))
      end

      def delete_blob(blob)
        delete(blob.file.key)
      end

      def blob(key)
        return nil unless exists?(key)

        signed_url = sign_url(partitioned_key(key), verb: 'get', expires_in_seconds: 3600)
        StorageBlob.new(key, signed_url:)
      end

      def files_for
        # POC - not sure if this is needed
        raise NotImplementedError.new('files_for is not implemented in StorageCliClient')
      end

      def ensure_bucket_exists
        # POC - not sure if this is needed
      end

      private

      def run_cli(command, *args, allow_exit_code_three: false)
        logger.info("[storage_cli_client] Running storage-cli: #{@cli_path} -c #{@config_file} #{command} #{args.join(' ')}")

        begin
          stdout, stderr, status = Open3.capture3(@cli_path, '-c', @config_file, command, *args)
        rescue StandardError => e
          raise BlobstoreError.new(e.inspect)
        end

        unless status.success? || (allow_exit_code_three && status.exitstatus == 3)
          raise "storage-cli #{command} failed with exit code #{status.exitstatus}, output: '#{stdout}', error: '#{stderr}'"
        end

        [stdout, status]
      end

      def sign_url(key, verb:, expires_in_seconds:)
        stdout, _status = run_cli('sign', key, verb.to_s.downcase, "#{expires_in_seconds}s")
        stdout.strip
      end

      def cli_path
        raise NotImplementedError
      end

      def build_config(fog_connection)
        raise NotImplementedError
      end

      def write_config_file(config)
        config_dir = File.join(tmpdir, 'blobstore-configs')
        FileUtils.mkdir_p(config_dir)

        config_file_path = File.join(config_dir, "#{@directory_key}.json")
        File.open(config_file_path, 'w', 0o600) do |f|
          f.write(Oj.dump(config))
        end
        config_file_path
      end

      def tmpdir
        VCAP::CloudController::Config.config.get(:directories, :tmpdir)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.storage_cli_client')
      end
    end
  end
end
