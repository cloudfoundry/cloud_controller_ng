module Fog
  module Google
    class StorageJSON
      class Real
        # Delete an Google Storage bucket
        # https://cloud.google.com/storage/docs/json_api/v1/buckets/delete
        #
        # @param bucket_name [String] Name of bucket to delete
        def delete_bucket(bucket_name)
          @storage_json.delete_bucket(bucket_name)
        end
      end

      class Mock
        def delete_bucket(_bucket_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
