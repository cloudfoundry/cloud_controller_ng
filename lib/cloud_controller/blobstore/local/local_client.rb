require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/errors'
require 'cloud_controller/blobstore/local/local_blob'
require 'fileutils'
require 'digest'

module CloudController
  module Blobstore
    class LocalClient < BaseClient
      attr_reader :root_dir

      def initialize(
        directory_key:,
        base_path:,
        root_dir: nil,
        min_size: nil,
        max_size: nil,
        use_temp_storage: false
      )
        @directory_key = directory_key
        @use_temp_storage = use_temp_storage
        @root_dir      = root_dir
        @min_size      = min_size || 0
        @max_size      = max_size

        setup_storage_path(base_path)
      end

      def local?
        true
      end

      def exists?(key)
        File.exist?(file_path(key))
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))
        FileUtils.cp(file_path(source_key), destination_path)
        File.chmod(mode, destination_path) if mode
      rescue Errno::ENOENT
        raise FileNotFound.new("Could not find object '#{source_key}'")
      end

      def cp_to_blobstore(source_path, destination_key)
        start     = Time.now.utc
        log_entry = 'blobstore.cp-skip'

        logger.info('blobstore.cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)

        size = File.size(source_path)
        if within_limits?(size)
          destination = file_path(destination_key)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source_path, destination)
          log_entry = 'blobstore.cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry, destination_key: destination_key, duration_seconds: duration, size: size)
      rescue Errno::ENOENT => e
        raise FileNotFound.new("Could not find source file '#{source_path}': #{e.message}")
      end

      def cp_file_between_keys(source_key, destination_key)
        source      = file_path(source_key)
        destination = file_path(destination_key)

        raise FileNotFound.new("Could not find object '#{source_key}'") unless File.exist?(source)

        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
      end

      def delete(key)
        path = file_path(key)
        FileUtils.rm_f(path)
        cleanup_empty_parent_directories(path)
      end

      def blob(key)
        path = file_path(key)
        return unless File.exist?(path)

        LocalBlob.new(key: partitioned_key(key), file_path: path)
      end

      def delete_blob(blob)
        path = File.join(@base_path, blob.key)
        FileUtils.rm_f(path)
        cleanup_empty_parent_directories(path)
      end

      def delete_all(_=nil)
        FileUtils.rm_rf(@base_path)
        FileUtils.mkdir_p(@base_path)
      end

      def delete_all_in_path(path)
        dir = File.join(@base_path, path)
        FileUtils.rm_rf(dir) if File.directory?(dir)
      end

      def files_for(prefix, _ignored_directory_prefixes=[])
        pattern = File.join(@base_path, prefix, '**', '*')
        Enumerator.new do |yielder|
          Dir.glob(pattern).each do |file_path|
            next unless File.file?(file_path)

            relative_path = file_path.sub("#{@base_path}/", '')
            yielder << LocalBlob.new(key: relative_path, file_path: file_path)
          end
        end
      end

      def ensure_bucket_exists
        FileUtils.mkdir_p(@base_path)
      end

      private

      def setup_storage_path(base_path)
        if use_temp_storage?
          @base_path = Dir.mktmpdir(['cc-blobstore-', "-#{@directory_key}"])
          logger.info('storage-mode', mode: 'temp', directory_key: @directory_key, path: @base_path)
          register_cleanup_hook
        else
          raise ArgumentError.new('local_blobstore_path is required for persistent storage') if base_path.nil?

          @base_path = File.join(base_path, @directory_key)
          FileUtils.mkdir_p(@base_path)
          logger.info('storage-mode', mode: 'persistent', directory_key: @directory_key, path: @base_path)
        end
      end

      def file_path(key)
        File.join(@base_path, partitioned_key(key))
      end

      def use_temp_storage?
        @use_temp_storage
      end

      def register_cleanup_hook
        # Register cleanup handler for temp storage mode
        at_exit do
          cleanup_temp_storage
        end
      end

      def cleanup_temp_storage
        return unless use_temp_storage? && @base_path && File.directory?(@base_path)

        logger.info('temp-storage-cleanup', directory_key: @directory_key, path: @base_path)
        FileUtils.rm_rf(@base_path)
      rescue StandardError => e
        logger.error('temp-storage-cleanup-failed', error: e.message, path: @base_path)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.local_client')
      end

      def cleanup_empty_parent_directories(path)
        dir = File.dirname(path)
        # Walk up the directory tree, removing empty directories until we hit the base path
        while dir != @base_path && dir.start_with?(@base_path)
          break unless File.directory?(dir)
          break unless Dir.empty?(dir)

          FileUtils.rmdir(dir)
          dir = File.dirname(dir)
        end
      end
    end
  end
end
