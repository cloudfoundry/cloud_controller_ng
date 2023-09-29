module CloudController
  module Blobstore
    class FingerprintsCollection
      def initialize(fingerprints, root_path)
        raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'invalid :resources') unless fingerprints.is_a?(Array)

        @fingerprints = fingerprints
        @root_path = root_path
      end

      DEFAULT_FILE_MODE = 0o744

      def fingerprints
        @fingerprints.map do |fingerprint|
          {
            'fn' => validate_path(fingerprint['fn']),
            'size' => fingerprint['size'],
            'sha1' => fingerprint['sha1'],
            'mode' => parse_mode(fingerprint['mode'], fingerprint['fn'])
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

      def parse_mode(raw_mode, filename)
        mode = raw_mode ? raw_mode.to_i(8) : DEFAULT_FILE_MODE
        unless (mode & 0o600) == 0o600
          raise CloudController::Errors::ApiError.new_from_details('AppResourcesFileModeInvalid',
                                                                   "File mode '#{raw_mode}' with path '#{filename}' is invalid. Minimum file mode is '0600'")
        end
        mode
      end

      def validate_path(file_name)
        checker = VCAP::CloudController::FilePathChecker
        invalid_path!(file_name) unless checker.safe_path? file_name, @root_path
        file_name
      end

      def invalid_path!(file_name)
        raise CloudController::Errors::ApiError.new_from_details('AppResourcesFilePathInvalid', "File path '#{file_name}' is not safe.")
      end
    end
  end
end
