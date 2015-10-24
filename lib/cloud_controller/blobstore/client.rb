require 'fileutils'
require 'find'
require 'fog'
require 'cloud_controller/blobstore/directory'
require 'cloud_controller/blobstore/blob'
require 'cloud_controller/blobstore/idempotent_directory'

module CloudController
  module Blobstore
    class Client
      class FileNotFound < StandardError
      end

      DEFAULT_BATCH_SIZE = 1000

      def initialize(connection_config, directory_key, cdn=nil, root_dir=nil, min_size=nil, max_size=nil)
        @root_dir = root_dir
        @connection_config = connection_config
        @directory_key = directory_key
        @cdn = cdn
        @min_size = min_size || 0
        @max_size = max_size
      end

      def local?
        @connection_config[:provider].downcase == 'local'
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

      def cp_r_to_blobstore(source_dir)
        Find.find(source_dir).each do |path|
          next unless File.file?(path)
          next unless within_limits?(File.size(path))

          sha1 = Digester.new.digest_path(path)
          next if exists?(sha1)

          cp_to_blobstore(path, sha1)
        end
      end

      def cp_to_blobstore(source_path, destination_key, retries=2)
        start = Time.now.utc
        logger.info('blobstore.cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)
        size = -1
        log_entry = 'blobstore.cp-skip'

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          begin
            mime_type = MIME::Types.of(source_path).first.try(:content_type)

            files.create(
              key: partitioned_key(destination_key),
              body: file,
              content_type: mime_type || 'application/zip',
              public: local?,
            )
          # work around https://github.com/fog/fog/issues/3137
          # and Fog raising an EOFError SocketError intermittently
          rescue SystemCallError, Excon::Errors::SocketError, Excon::Errors::BadRequest => e
            logger.debug('blobstore.cp-retry',
                         error: e,
                         destination_key: destination_key,
                         remaining_retries: retries
                        )
            retries -= 1
            retry unless retries < 0
            raise e
          end

          log_entry = 'blobstore.cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: duration,
                    size: size,
                   )
      end

      def cp_file_between_keys(source_key, destination_key)
        source_file = file(source_key)
        raise FileNotFound if source_file.nil?
        source_file.copy(@directory_key, partitioned_key(destination_key))

        dest_file = file(destination_key)

        if local?
          dest_file.public = 'public-read'
        end
        dest_file.save
      end

      def delete_all(page_size=DEFAULT_BATCH_SIZE)
        logger.info("Attempting to delete all files in #{@directory_key}/#{@root_dir} blobstore")

        delete_files(files_for(@root_dir), page_size)
      end

      def delete_all_in_path(path)
        logger.info("Attempting to delete all files in blobstore #{@directory_key} under path #{@directory_key}/#{partitioned_key(path)}")

        delete_files(files_for(partitioned_key(path)), DEFAULT_BATCH_SIZE)
      end

      def files_for(prefix)
        if connection.is_a? Fog::Storage::Local::Real
          directory = connection.directories.get(File.join(dir.key, prefix || ''))
          directory ? directory.files : []
        else
          connection.directories.get(dir.key, prefix: prefix).files
        end
      end

      def delete(key)
        blob_file = file(key)
        delete_file(blob_file) if blob_file
      end

      def delete_blob(blob)
        delete_file(blob.file) if blob.file
      end

      def download_uri(key)
        b = blob(key)
        b.download_url if b
      end

      def blob(key)
        f = file(key)
        Blob.new(f, @cdn) if f
      end

      # Deprecated should not allow to access underlying files
      def files
        dir.files
      end

      private

      def delete_file(file)
        file.destroy
      end

      def delete_files(files_to_delete, page_size)
        if connection.respond_to?(:delete_multiple_objects)
          # AWS needs the file key to work; other providers with multiple delete
          # are currently not supported. When support is added this code may
          # need an update.
          each_slice(files_to_delete, page_size) do |file_group|
            connection.delete_multiple_objects(@directory_key, file_group.map(&:key))
          end
        else
          files_to_delete.each { |f| delete_file(f) }
        end
      end

      def each_slice(files, batch_size, &blk)
        batch = []
        files.each do |f|
          batch << f

          if batch.length == batch_size
            blk.call(batch)
            batch = []
          end
        end

        if batch.length > 0
          blk.call(batch)
        end
      end

      def file(key)
        files.head(partitioned_key(key))
      end

      def partitioned_key(key)
        key = key.to_s.downcase
        key = File.join(key[0..1], key[2..3], key)
        if @root_dir
          key = File.join(@root_dir, key)
        end
        key
      end

      def dir
        @dir ||= directory.get_or_create
      end

      def directory
        @directory ||= IdempotentDirectory.new(Directory.new(connection, @directory_key))
      end

      def connection
        options = @connection_config
        options = options.merge(endpoint: '') if local?
        @connection ||= Fog::Storage.new(options)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore')
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end
    end
  end
end
