module Fog
  module Aliyun
    class Storage
      class Real

        # Get access control list for an S3 object
        #
        # @param bucket_name [String] name of bucket containing object
        # @param object_name [String] name of object to get access control list for
        # @param options [Hash]
        # @option options versionId [String] specify a particular version to retrieve

        def get_object_acl(bucket_name, object_name, options = {})
          unless bucket_name
            raise ArgumentError.new('bucket_name is required')
          end
          unless object_name
            raise ArgumentError.new('object_name is required')
          end

          # At present, sdk does not support versionId
          # if version_id = options.delete('versionId')
          #   query['versionId'] = version_id
          # end
          @oss_protocol.get_object_acl(bucket_name, object_name)
        end
      end
    end
  end
end
