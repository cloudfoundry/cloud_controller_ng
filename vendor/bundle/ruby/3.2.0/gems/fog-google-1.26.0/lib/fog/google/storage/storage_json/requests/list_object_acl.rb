module Fog
  module Google
    class StorageJSON
      class Real
        # List access control list for an Google Storage object
        # https://cloud.google.com/storage/docs/json_api/v1/objectAccessControls/get
        #
        # @param bucket_name [String] Name of bucket object is in
        # @param object_name [String] Name of object to add ACL to
        # @return [Google::Apis::StorageV1::ObjectAccessControls]
        def list_object_acl(bucket_name, object_name, generation: nil)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name

          @storage_json.list_object_access_controls(bucket_name, object_name,
                                                    :generation => generation)
        end
      end

      class Mock
        def list_object_acl(_bucket_name, _object_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
