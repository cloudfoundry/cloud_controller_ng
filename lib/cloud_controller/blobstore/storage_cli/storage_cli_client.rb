require 'open3'
require 'tempfile'
require 'tmpdir'
require 'fileutils'
require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/storage_cli/storage_cli_blob'

module CloudController
  module Blobstore
    class StorageCliClient < BaseClient
      attr_reader :root_dir, :min_size, :max_size

      @registry = {}

      class << self
        attr_reader :registry

        def register(provider, klass)
          registry[provider.to_s] = klass
        end

        def build(directory_key:, root_dir:, resource_type: nil, min_size: nil, max_size: nil)
          raise 'Missing resource_type' if resource_type.nil?

          cfg = fetch_and_validate_config!(resource_type)
          provider = cfg['provider']

          key        = provider.to_s
          impl_class = registry[key] || registry[key.downcase] || registry[key.upcase]
          raise "No storage CLI client registered for provider #{provider}" unless impl_class

          impl_class.new(provider:, directory_key:, root_dir:, resource_type:, min_size:, max_size:)
        end

        def fetch_and_validate_config!(resource_type)
          path = config_path_for!(resource_type)

          begin
            json = Oj.load(File.read(path))
          rescue StandardError => e
            raise BlobstoreError.new("Failed to parse storage-cli config JSON at #{path}: #{e.message}")
          end

          validate_required_keys!(json, path)
          json
        end

        def config_path_for!(resource_type)
          key =
            case resource_type.to_s
            when 'droplets', 'buildpack_cache' then :storage_cli_config_file_droplets
            when 'buildpacks'                  then :storage_cli_config_file_buildpacks
            when 'packages'                    then :storage_cli_config_file_packages
            when 'resource_pool'               then :storage_cli_config_file_resource_pool
            else
              raise BlobstoreError.new("Unknown resource_type: #{resource_type}")
            end

          path = VCAP::CloudController::Config.config.get(key)
          raise BlobstoreError.new("storage-cli config file not found or not readable at: #{path.inspect}") unless path && File.file?(path) && File.readable?(path)

          path
        end

        def validate_required_keys!(json, path)
          validate_provider!(json, path)
          required = %w[
            account_key
            account_name
            container_name
            environment
          ]
          missing = required.reject { |k| json.key?(k) && !json[k].to_s.strip.empty? }
          return if missing.empty?

          raise BlobstoreError.new("Missing required keys in config file #{path}: #{missing.join(', ')} (json: #{json})")
        end

        def validate_provider!(json, path)
          provider = json['provider']
          return unless provider.nil? || provider.to_s.strip.empty?

          raise BlobstoreError.new("No provider specified in config file: #{path.inspect} json: #{json}")
        end
      end

      def initialize(provider:, directory_key:, resource_type:, root_dir:, min_size: nil, max_size: nil)
        @cli_path = cli_path
        @directory_key = directory_key
        @resource_type = resource_type.to_s
        @root_dir = root_dir
        @min_size = min_size || 0
        @max_size = max_size
        @provider = provider

        file_path = case @resource_type
                    when 'droplets', 'buildpack_cache'
                      VCAP::CloudController::Config.config.get(:storage_cli_config_file_droplets)
                    when 'buildpacks'
                      VCAP::CloudController::Config.config.get(:storage_cli_config_file_buildpacks)
                    when 'packages'
                      VCAP::CloudController::Config.config.get(:storage_cli_config_file_packages)
                    when 'resource_pool'
                      VCAP::CloudController::Config.config.get(:storage_cli_config_file_resource_pool)
                    else
                      raise BlobstoreError.new("Unknown resource_type: #{@resource_type}")
                    end

        unless file_path && File.file?(file_path) && File.readable?(file_path)
          raise BlobstoreError.new("storage-cli config file not found or not readable at: #{file_path.inspect}")
        end

        begin
          VCAP::CloudController::YAMLConfig.safe_load_file(file_path)
        rescue StandardError => e
          raise BlobstoreError.new("Failed to load storage-cli config at #{file_path}: #{e.message}")
        end

        @config_file = file_path
        logger.info('storage_cli_config_selected', resource_type: @resource_type, path: @config_file)
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
        run_cli('copy', partitioned_key(source_key), partitioned_key(destination_key))
      end

      def delete_all(_=nil)
        # page_size is currently not considered. Azure SDK / API has a limit of 5000
        # Currently, storage-cli does not support bulk deletion.
        run_cli('delete-recursive', @root_dir)
      end

      def delete_all_in_path(path)
        # Currently, storage-cli does not support bulk deletion.
        run_cli('delete-recursive', partitioned_key(path))
      end

      def delete(key)
        run_cli('delete', partitioned_key(key))
      end

      def delete_blob(blob)
        delete(blob.key)
      end

      def blob(key)
        properties = properties(key)
        return nil if properties.nil? || properties.empty?

        signed_url = sign_url(partitioned_key(key), verb: 'get', expires_in_seconds: 3600)
        StorageCliBlob.new(key, properties:, signed_url:)
      end

      def files_for(prefix, _ignored_directory_prefixes=[])
        files, _status = run_cli('list', prefix)
        files.split("\n").map(&:strip).reject(&:empty?).map { |file| StorageCliBlob.new(file) }
      end

      def ensure_bucket_exists
        run_cli('ensure-bucket-exists')
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

      def properties(key)
        stdout, _status = run_cli('properties', partitioned_key(key))
        # stdout is expected to be in JSON format - raise an error if it is nil, empty or something unexpected
        raise BlobstoreError.new("Properties command returned empty output for key: #{key}") if stdout.nil? || stdout.empty?

        begin
          properties = Oj.load(stdout)
        rescue StandardError => e
          raise BlobstoreError.new("Failed to parse json properties for key: #{key}, error: #{e.message}")
        end

        properties
      end

      def cli_path
        raise NotImplementedError
      end

      def build_config(connection_config)
        raise NotImplementedError
      end

      def write_config_file(config)
        # TODO: Consider to move the config generation into capi-release
        config_dir = File.join(tmpdir, 'blobstore-configs')
        FileUtils.mkdir_p(config_dir)

        config_file_path = File.join(config_dir, "#{@directory_key}.json")
        File.open(config_file_path, 'w', 0o600) do |f|
          f.write(Oj.dump(config.transform_keys(&:to_s)))
        end
        config_file_path
      end

      def tmpdir
        VCAP::CloudController::Config.config.get(:directories, :tmpdir)
      rescue StandardError
        # Fallback to a temporary directory if the config is not set (e.g. for cc-deployment-updater
        Dir.mktmpdir('cc_blobstore')
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.storage_cli_client')
      end
    end
  end
end
