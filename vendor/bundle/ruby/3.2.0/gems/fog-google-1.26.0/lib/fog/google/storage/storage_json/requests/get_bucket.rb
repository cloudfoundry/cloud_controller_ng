module Fog
  module Google
    class StorageJSON
      class Real
        # List information about objects in an Google Storage bucket #
        # https://cloud.google.com/storage/docs/json_api/v1/buckets#resource
        #
        # @param bucket_name [String]
        #   Name of bucket to list
        # @param [Fixnum] if_metageneration_match
        #   Makes the return of the bucket metadata conditional on whether the bucket's
        #   current metageneration matches the given value.
        # @param [Fixnum] if_metageneration_not_match
        #   Makes the return of the bucket metadata conditional on whether the bucket's
        #   current metageneration does not match the given value.
        # @param [String] projection
        #   Set of properties to return. Defaults to noAcl.
        # @return [Google::Apis::StorageV1::Bucket]
        def get_bucket(bucket_name,
                       if_metageneration_match: nil,
                       if_metageneration_not_match: nil,
                       projection: nil)
          raise ArgumentError.new("bucket_name is required") unless bucket_name

          @storage_json.get_bucket(
            bucket_name,
            :if_metageneration_match => if_metageneration_match,
            :if_metageneration_not_match => if_metageneration_not_match,
            :projection => projection
          )
        end
      end

      class Mock
        def get_bucket(_bucket_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
