require 'cloud_controller/blobstore/blob'
require 'cloud_controller/blobstore/blob_key_generator'

module CloudController
  module Blobstore
    class BaseClient
      def cp_r_to_blobstore(source_dir)
        Find.find(source_dir).each do |path|
          next unless File.file?(path)
          next unless within_limits?(File.size(path))

          sha1 = Digester.new.digest_path(path)
          next if exists?(sha1)

          cp_to_blobstore(path, sha1)
        end
      end

      def cp_to_blobstore(_, _)
        raise NotImplementedError
      end

      private

      def partitioned_key(key)
        key             = key.to_s.downcase
        partitioned_key = BlobKeyGenerator.full_path_from_key(key)
        if @root_dir
          partitioned_key = File.join(@root_dir, partitioned_key)
        end
        partitioned_key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end
    end
  end
end
