require 'fileutils'
require 'find'
require 'mime-types'
require 'cloud_controller/blobstore/fog/providers'
require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/fog/fog_blob'
require 'cloud_controller/blobstore/fog/cdn'
require 'cloud_controller/blobstore/errors'

module CloudController
  module Blobstore
    class FogClient < BaseClient
      attr_reader :root_dir

      DEFAULT_BATCH_SIZE = 1000
      DEPRECATION_MESSAGE = '[DEPRECATION WARNING] The fog blobstore client is DEPRECATED and will be REMOVED. ' \
                            "Please migrate to blobstore_type 'storage-cli' as soon as possible. " \
                            'See https://github.com/cloudfoundry/community/blob/main/toc/rfc/rfc-0043-cc-blobstore-storage-cli.md for details.'.freeze

      def initialize(connection_config:,
                     directory_key:,
                     cdn: nil,
                     root_dir: nil,
                     min_size: nil,
                     max_size: nil)
)
        @root_dir = root_dir
        @connection_config = connection_config
        @directory_key = directory_key
        @cdn = cdn
        @min_size = min_size || 0
        @max_size = max_size
        logger.warn('blobstore.fog-deprecated', message: DEPRECATION_MESSAGE)
      end

      def local?
        false
      end

      def exists?(key)
        !file(key).nil?
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))
        File.open(destination_path, 'wb') do |file|
          (@cdn || files).get(partitioned_key(source_key)) do |*chunk|
            file.write(chunk[0])
          end
          file.chmod(mode) if mode
        end
      end

      def cp_to_blobstore(source_path, destination_key)
        start = Time.now.utc
        logger.info('blobstore.cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)
        size = -1
        log_entry = 'blobstore.cp-skip'

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          mime_type = MIME::Types.of(source_path).first.try(:content_type)

          options = {
            key: partitioned_key(destination_key),
            body: file,
            content_type: mime_type || 'application/zip',
            public: false
          }.merge(formatted_storage_options)

          files.create(options)

          log_entry = 'blobstore.cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: duration,
                    size: size)
      end

      def cp_file_between_keys(source_key, destination_key)
        source_file = file(source_key)
        raise FileNotFound if source_file.nil?

        source_file.copy(@directory_key, partitioned_key(destination_key), formatted_storage_options)
      end

      def delete_all(page_size=DEFAULT_BATCH_SIZE)
        logger.info("Attempting to delete all files in #{@directory_key}/#{@root_dir} blobstore")

        delete_files(files_for(@root_dir), page_size)
      end

      def delete_all_in_path(path)
        logger.info("Attempting to delete all files in blobstore #{@directory_key} under path #{@directory_key}/#{partitioned_key(path)}")

        delete_files(files_for(partitioned_key(path)), DEFAULT_BATCH_SIZE)
      end

      def delete(key)
        blob_file = file(key)
        delete_file(blob_file) if blob_file
      end

      def delete_blob(blob)
        delete_file(blob.file) if blob.file
      end

      def blob(key, **)
        f = file(key)
        FogBlob.new(f, @cdn) if f
      end

      def files_for(prefix, _ignored_directory_prefixes=[])
        connection.directories.get(dir.key, prefix:).files
      end

      def ensure_bucket_exists
        options = { max_keys: 1 }
        connection.directories.get(@directory_key, options) || connection.directories.create(key: @directory_key, public: false)
      end

      private

      def files
        dir.files
      end

      def formatted_storage_options
        {}
      end

      def delete_file(file)
        file.destroy
      end

      def delete_files(files_to_delete, page_size)
        if connection.respond_to?(:delete_multiple_objects)
          each_slice(files_to_delete, page_size) do |file_group|
            connection.delete_multiple_objects(@directory_key, file_group.map(&:key))
          end
        else
          files_to_delete.each { |f| delete_file(f) }
        end
      end

      def each_slice(files, batch_size)
        batch = []
        files.each do |f|
          batch << f

          if batch.length == batch_size
            yield(batch)
            batch = []
          end
        end

        return if batch.empty?

        yield(batch)
      end

      def file(key)
        files.head(partitioned_key(key))
      end

      def dir
        @dir ||= connection.directories.new(key: @directory_key)
      end

      def connection
        options = @connection_config
        blobstore_timeout = options.delete(:blobstore_timeout)
        connection_options = options[:connection_options] || {}
        connection_options = connection_options.merge(read_timeout: blobstore_timeout, write_timeout: blobstore_timeout)
        options = options.merge(connection_options:)
        @connection ||= Fog::Storage.new(options)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore')
      end
    end
  end
end
