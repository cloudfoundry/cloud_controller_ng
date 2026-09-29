require 'cloud_controller/blobstore/blob'
require 'cloud_controller/blobstore/blob_key_generator'
require 'utils/workpool'

module CloudController
  module Blobstore
    class BaseClient
      def cp_r_to_blobstore(source_dir)
        workpool_size = 25
        workpool = WorkPool.new(workpool_size, store_exceptions: true)

        Find.find(source_dir).each do |path|
          # Throttle submission if queue is getting too large to prevent unbounded memory growth.
          while workpool.queue_size >= workpool_size * 2
            sleep 0.01
          end

          workpool.submit(path) do |file_path|
            next unless File.file?(file_path)
            next unless within_limits?(File.size(file_path))
            next unless File.stat(file_path).mode.to_s(8)[3..5].to_i(8) >= 0o600

            sha1 = Digester.new.digest_path(file_path)
            next if exists?(sha1)

            cp_to_blobstore(file_path, sha1)
          end
        end

        workpool.drain
        raise workpool.exceptions.first if workpool.exceptions.any?
      end

      def cp_to_blobstore(_, _)
        raise NotImplementedError
      end

      private

      def partitioned_key(key)
        key             = key.to_s.downcase
        partitioned_key = BlobKeyGenerator.full_path_from_key(key)
        partitioned_key = File.join(@root_dir, partitioned_key) if @root_dir
        partitioned_key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end
    end
  end
end
