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

      RESOURCE_TYPE_KEYS = {
        'droplets' => :storage_cli_config_file_droplets,
        'buildpack_cache' => :storage_cli_config_file_droplets,
        'buildpacks' => :storage_cli_config_file_buildpacks,
        'packages' => :storage_cli_config_file_packages,
        'resource_pool' => :storage_cli_config_file_resource_pool
      }.freeze

      # Native storage-cli type names supported by CC
      STORAGE_CLI_TYPES = %w[azurebs alioss s3 gcs dav].freeze

      def initialize(directory_key:, resource_type:, root_dir:, min_size: nil, max_size: nil, metrics_updater: nil)
        raise 'Missing resource_type' if resource_type.nil?

        config_file_path = config_path_for(resource_type)
        cfg = fetch_config(resource_type)

        provider = cfg['provider']&.to_s
        raise BlobstoreError.new("No provider specified in config file: #{File.basename(config_file_path)}") if provider.nil? || provider.empty?

        @storage_type = provider if STORAGE_CLI_TYPES.include?(provider)

        raise "Unknown provider: #{provider}. Supported storage-cli types: #{STORAGE_CLI_TYPES.join(', ')}" unless @storage_type

        @cli_path = cli_path
        @config_file = config_file_path
        @directory_key = directory_key
        @resource_type = resource_type.to_s
        @root_dir = root_dir
        @min_size = min_size || 0
        @max_size = max_size
        @metrics_updater = metrics_updater
      end

      def fetch_config(resource_type)
        path = config_path_for(resource_type)
        validate_config_path!(path)

        json = fetch_json(path)
        validate_json_object!(json, path)
        json
      end

      def config_path_for(resource_type)
        normalized = resource_type.to_s
        key = RESOURCE_TYPE_KEYS.fetch(normalized) do
          raise BlobstoreError.new("Unknown resource_type: #{resource_type}")
        end
        VCAP::CloudController::Config.config.get(key)
      end

      def fetch_json(path)
        Oj.load(File.read(path))
      rescue JSON::ParserError, EncodingError => e
        raise BlobstoreError.new("Failed to parse storage-cli JSON at #{path}: #{e.message}")
      end

      def validate_config_path!(path)
        return if path && File.file?(path) && File.readable?(path)

        raise BlobstoreError.new("Storage-cli config file not found or not readable at: #{path.inspect}")
      end

      def validate_json_object!(json, path)
        raise BlobstoreError.new("Config at #{path} must be a JSON object") unless json.is_a?(Hash)
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
        size      = nil

        logger.info('cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)

        state = { run_cli_called: false, run_cli_succeeded: false, skip_metric_emitted: false }
        begin
          File.open(source_path) do |file|
            size = file.size
            log_entry = cp_put_blob(source_path, destination_key, size, start, state)
          end
        rescue Interrupt, SignalException
          log_entry = 'cp-error'
          emit_signal_metric_if_needed(start, state)
          raise
        rescue StandardError
          log_entry = 'cp-error'
          safe_emit_metrics('put', -3, Time.now.utc - start, 'cp_to_blobstore') unless state[:run_cli_called]
          raise
        ensure
          safe_log_finish(log_entry, destination_key, start, size)
        end
      end

      def cp_put_blob(source_path, destination_key, size, start, state)
        if within_limits?(size)
          state[:run_cli_called] = true
          run_put_with_fatal_rescue(source_path, destination_key, size, start, state)
          state[:run_cli_succeeded] = true
          'cp-finish'
        else
          safe_emit_metrics('put', -4, Time.now.utc - start, 'cp_to_blobstore skip')
          state[:skip_metric_emitted] = true
          'cp-skip'
        end
      end

      def run_put_with_fatal_rescue(source_path, destination_key, size, start, state)
        run_cli('put', source_path, partitioned_key(destination_key), blob_size: size)
      rescue StandardError
        # run_cli already emitted a metric before re-raising; nothing to do here.
        raise
      rescue Exception => e # rubocop:disable Lint/RescueException
        # Catches fatal exceptions (NoMemoryError etc.) and signals (Interrupt, SignalException)
        # that StandardError does not cover.
        #
        # For signals: if Interrupt fired after run_cli returned, run_cli already emitted
        # exit_code=0 — mark succeeded so the outer handler skips the -6 emit.
        # For fatal exceptions: run_cli has not emitted, so emit -7 here.
        if e.is_a?(Interrupt) || e.is_a?(SignalException)
          state[:run_cli_succeeded] = true
        else
          safe_emit_metrics('put', -7, Time.now.utc - start, 'fatal exception in run_cli')
        end
        raise
      end

      def emit_signal_metric_if_needed(start, state)
        return if state[:run_cli_succeeded] || state[:skip_metric_emitted]

        # -5: signal before CLI was invoked; -6: signal mid-execution after CLI was invoked.
        signal_exit_code = state[:run_cli_called] ? -6 : -5
        safe_emit_metrics('put', signal_exit_code, Time.now.utc - start, 'signal in cp_to_blobstore')
      end

      def safe_emit_metrics(operation, exit_code, duration, context, blob_size: nil)
        emit_storage_cli_metrics(operation, exit_code, duration, blob_size: blob_size)
      rescue StandardError => e
        logger.warn("emit_storage_cli_metrics failed in #{context}: #{e.inspect}")
      end

      def safe_log_finish(log_entry, destination_key, start, size)
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: Time.now.utc - start,
                    size: size)
      rescue StandardError => e
        logger.warn("cp_to_blobstore ensure log failed: #{e.inspect}")
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

      def blob(key, use_internal_url: false)
        properties = properties(key)
        return nil if properties.nil? || properties.empty?

        signed_url = sign_url(partitioned_key(key), verb: 'get', expires_in_seconds: 3600, use_internal_url: use_internal_url)
        StorageCliBlob.new(key, properties: properties, signed_url: signed_url)
      end

      def files_for(prefix, _ignored_directory_prefixes=[])
        files, _status = run_cli('list', prefix)
        files.split("\n").map(&:strip).reject(&:empty?).map { |file| StorageCliBlob.new(file) }
      end

      def ensure_bucket_exists
        run_cli('ensure-storage-exists')
      end

      private

      def additional_flags
        flags_string = VCAP::CloudController::Config.config.get(:storage_cli_optional_flags)
        return [] if flags_string.nil? || flags_string.empty?

        flags_string.split
      end

      def run_cli(command, *args, allow_exit_code_three: false, blob_size: nil)
        logger.debug("running storage-cli: #{@cli_path} -s #{@storage_type} -c #{@config_file} #{additional_flags.join(' ')} #{command} #{args.join(' ')}")

        t = Time.now.utc
        stdout, stderr, status = capture_cli(command, args, t)
        duration = Time.now.utc - t

        stderr.split("\n").each { |line| logger.info("[INFO] storage-cli: #{line}") }

        exit_code = resolve_exit_code(status)
        success = status.success? || (allow_exit_code_three && status.exitstatus == 3)

        unless success
          safe_emit_metrics(command, exit_code, duration, 'run_cli failure', blob_size: blob_size)
          raise "storage-cli #{command} failed with exit code #{exit_code.inspect}, output: '#{stdout}', error: '#{stderr}'"
        end

        # Remap allowed exit 3 (e.g. key-not-found on exists) to 0 so Prometheus only
        # records non-zero exit_codes for genuine failures.
        metric_exit_code = allow_exit_code_three && exit_code == 3 ? 0 : exit_code
        safe_emit_metrics(command, metric_exit_code, duration, 'run_cli success', blob_size: blob_size)

        [stdout, status]
      end

      def capture_cli(command, args, start_time)
        Open3.capture3(@cli_path, '-s', @storage_type, '-c', @config_file, *additional_flags, command, *args)
      rescue StandardError => e
        # exit_code=-1 is a sentinel for spawn failures (binary missing, permission denied).
        safe_emit_metrics(command, -1, Time.now.utc - start_time, 'spawn error')
        raise BlobstoreError.new(e.inspect)
      end

      def resolve_exit_code(status)
        if status.exitstatus
          status.exitstatus
        elsif status.termsig
          128 + status.termsig
        else
          # exit_code=-2: process exited with neither exitstatus nor termsig (platform anomaly).
          -2
        end
      end

      def sign_url(key, verb:, expires_in_seconds:, use_internal_url: false)
        command =
          if @storage_type == 'dav'
            use_internal_url ? 'sign-internal' : 'sign-public'
          else
            'sign'
          end
        stdout, _status = run_cli(command, key, verb.to_s.downcase, "#{expires_in_seconds}s")
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
        ENV['STORAGE_CLI_PATH'] || '/var/vcap/packages/storage-cli/bin/storage-cli'
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

      def emit_storage_cli_metrics(operation, exit_code, duration_seconds, blob_size: nil)
        return if @metrics_updater.nil?

        @metrics_updater.report_storage_cli_metrics(operation:, exit_code:, duration_seconds:, blob_size:)
      end
    end
  end
end
