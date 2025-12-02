module Fog
  module Google
    class StorageJSON
      class Real
        # Get access control list entry for an Google Storage bucket
        # @see https://cloud.google.com/storage/docs/json_api/v1/bucketAccessControls/get
        #
        # @param bucket_name [String]
        #   Name of bucket
        # @param entity [String]
        #   The entity holding the permission. Can be user-userId,
        #   user-emailAddress, group-groupId, group-emailAddress, allUsers,
        #   or allAuthenticatedUsers.
        # @return [Google::Apis::StorageV1::BucketAccessControls]
        def get_bucket_acl(bucket_name, entity)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("entity is required") unless entity

          @storage_json.get_bucket_access_control(bucket_name, entity)
        end
      end

      class Mock
        def get_bucket_acl(_bucket_name, _entity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
