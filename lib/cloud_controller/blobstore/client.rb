require "fileutils"
require "find"
require "fog"
require "cloud_controller/blobstore/directory"
require "cloud_controller/blobstore/blob"
require "cloud_controller/blobstore/idempotent_directory"

module CloudController
  module Blobstore
    class Client
      def initialize(connection_config, directory_key, cdn=nil, root_dir=nil, min_size=nil, max_size=nil)
        @root_dir = root_dir
        @connection_config = connection_config
        @directory_key = directory_key
        @cdn = cdn
        @min_size = min_size || 0
        @max_size = max_size
      end

      def local?
        @connection_config[:provider].downcase == "local"
      end

      def exists?(key)
        !file(key).nil?
      end

      def download_from_blobstore(source_key, destination_path)
        FileUtils.mkdir_p(File.dirname(destination_path))
        File.open(destination_path, "w") do |file|
          (@cdn || files).get(partitioned_key(source_key)) do |*chunk|
            file.write(chunk[0])
          end
        end
      end

      def cp_r_to_blobstore(source_dir)
        Find.find(source_dir).each do |path|
          next unless File.file?(path)
          next unless within_limits?(File.size(path))

          sha1 = Digest::SHA1.file(path).hexdigest
          next if exists?(sha1)

          cp_to_blobstore(path, sha1)
        end
      end

      def cp_to_blobstore(source_path, destination_key)
        start = Time.now
        logger.info("blobstore.cp-start", destination_key: destination_key, source_path: source_path, bucket: @directory_key)
        size = -1
        log_entry = "blobstore.cp-skip"

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          files.create(
            :key => partitioned_key(destination_key),
            :body => file,
            :public => local?,
          )

          log_entry = "blobstore.cp-finish"
        end

        duration = Time.now - start
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: duration,
                    size: size,
                    )
      end

      def delete(key)
        blob_file = file(key)
        blob_file.destroy if blob_file
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
        options = options.merge(:endpoint => "") if local?
        Fog::Storage.new(options)
      end

      def logger
        @logger ||= Steno.logger("cc.blobstore")
      end

      def within_limits?(size)
        size>=@min_size && (@max_size.nil? || size<=@max_size)
      end
    end
  end
end
