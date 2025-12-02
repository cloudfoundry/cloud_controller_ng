module Fog
  module Google
    class StorageJSON
      class Real
        # Fetch metadata for an object in Google Storage
        #
        # @param bucket_name [String] Name of bucket to read from
        # @param object_name [String] Name of object to read
        # @param options [Hash] Optional parameters
        # @see https://cloud.google.com/storage/docs/json_api/v1/objects/get
        #
        # @return [Google::Apis::StorageV1::Object]
        def get_object_metadata(bucket_name, object_name, options = {})
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name

          request_options = ::Google::Apis::RequestOptions.default.merge(options)
          @storage_json.get_object(bucket_name, object_name,
                                   :options => request_options)
        end
      end

      class Mock
        def get_object_metadata(_bucket_name, _object_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
