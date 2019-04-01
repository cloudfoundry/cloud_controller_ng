module CloudController
  module Blobstore
    class BlobKeyGenerator
      def self.key_from_full_path(path)
        split_path = path.split(File::Separator)
        File.join(split_path.drop(2))
      end

      def self.full_path_from_key(key)
        File.join(key[0..1], key[2..3], key)
      end
    end
  end
end
