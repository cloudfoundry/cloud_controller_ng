module CloudController
  module Blobstore
    class FingerprintsCollection
      def initialize(fingerprints)
        unless fingerprints.kind_of?(Array)
          raise VCAP::Errors::AppBitsUploadInvalid, "invalid :resources"
        end

        @fingerprints = fingerprints
      end

      def each(&block)
        @fingerprints.each do |fingerprint|
          block.yield fingerprint["fn"], fingerprint["sha1"]
        end
      end

      def storage_size
        @fingerprints.inject(0) do |sum, fingerprint|
          sum += fingerprint["size"]
        end
      end
    end
  end
end
