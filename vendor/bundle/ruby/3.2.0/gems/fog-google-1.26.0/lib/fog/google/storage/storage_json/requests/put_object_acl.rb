module Fog
  module Google
    class StorageJSON
      class Real
        # Change access control list for an Google Storage object
        #
        # @param bucket_name [String] name of bucket object is in
        # @param object_name [String] name of object to add ACL to
        # @param acl [Hash] ACL hash to add to bucket, see GCS documentation.
        #
        # @see https://cloud.google.com/storage/docs/json_api/v1/objectAccessControls/insert
        # @return [Google::Apis::StorageV1::ObjectAccessControl]
        def put_object_acl(bucket_name, object_name, acl)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name
          raise ArgumentError.new("acl is required") unless acl

          acl_object = ::Google::Apis::StorageV1::ObjectAccessControl.new(**acl)

          @storage_json.insert_object_access_control(
            bucket_name, object_name, acl_object
          )
        end
      end

      class Mock
        def put_object_acl(_bucket_name, _object_name, _acl)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
