module Fog
  module Google
    class StorageJSON
      class Real
        # Get access control list for an Google Storage bucket
        # @see https://cloud.google.com/storage/docs/json_api/v1/bucketAccessControls/list
        #
        # @param bucket_name [String] Name of bucket object is in
        # @return [Google::Apis::StorageV1::BucketAccessControls]
        def list_bucket_acl(bucket_name)
          raise ArgumentError.new("bucket_name is required") unless bucket_name

          @storage_json.list_bucket_access_controls(bucket_name)
        end
      end

      class Mock
        def list_bucket_acl(_bucket_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
