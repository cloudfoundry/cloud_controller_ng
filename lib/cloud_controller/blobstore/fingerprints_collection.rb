module CloudController
  module Blobstore
    class FingerprintsCollection
      def initialize(fingerprints)
        unless fingerprints.is_a?(Array)
          raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'invalid :resources')
        end

        @fingerprints = fingerprints
      end

      DEFAULT_FILE_MODE = 0744

      def fingerprints
        @fingerprints.map do |fingerprint|
          {
            'fn' => validate_path(fingerprint['fn']),
            'size' => fingerprint['size'],
            'sha1' => fingerprint['sha1'],
            'mode' => parse_mode(fingerprint['mode'])
          }
        end
      end

      def each(&block)
        fingerprints.each do |fingerprint|
          block.yield fingerprint['fn'], fingerprint['sha1'], fingerprint['mode']
        end
      end

      def storage_size
        @fingerprints.inject(0) do |sum, fingerprint|
          sum + fingerprint['size']
        end
      end

      private

      def parse_mode(raw_mode)
        mode = raw_mode ? raw_mode.to_i(8) : DEFAULT_FILE_MODE
        raise CloudController::Errors::ApiError.new_from_details('AppResourcesFileModeInvalid',
          "File mode '#{raw_mode}' is invalid. Minimum file mode is '0600'") unless (mode & 0600) == 0600
        mode
      end

      def validate_path(file_name)
        checker = VCAP::CloudController::FilePathChecker
        raise CloudController::Errors::ApiError.new_from_details('AppResourcesFilePathInvalid', "File path '#{file_name}' is not safe.") unless checker.safe_path? file_name
        file_name
      end
    end
  end
end
