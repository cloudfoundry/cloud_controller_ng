module Fog
  module Aliyun
    class Storage
      class Real

        # Delete multiple objects from OSS
        #
        # @param bucket_name [String] Name of bucket containing object to delete
        # @param object_names [Array]  Array of object names to delete
        #
        # @see https://help.aliyun.com/document_detail/31983.html

        def delete_multiple_objects(bucket_name, object_names, options = {})
          bucket = @oss_client.get_bucket(bucket_name)
          bucket.batch_delete_objects(object_names, options)
        end
      end
    end
  end
end
