require 'cloud_controller/blobstore/blob'

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
        key = key.to_s.downcase
        key = File.join(key[0..1], key[2..3], key)
        if @root_dir
          key = File.join(@root_dir, key)
        end
        key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end
    end
  end
end
