module Fog
  module Google
    class StorageJSON
      class Real
        # Change access control list for an Google Storage bucket
        # https://cloud.google.com/storage/docs/json_api/v1/bucketAccessControls/insert
        #
        # @param bucket_name [String] Name of bucket object is in
        # @param acl [Hash] ACL hash to add to bucket, see GCS documentation above
        # @return [Google::Apis::StorageV1::BucketAccessControl]
        def put_bucket_acl(bucket_name, acl = {})
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("acl is required") unless acl

          acl_update = ::Google::Apis::StorageV1::BucketAccessControl.new(**acl)
          @storage_json.insert_bucket_access_control(bucket_name, acl_update)
        end
      end

      class Mock
        def put_bucket_acl(_bucket_name, _acl)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
