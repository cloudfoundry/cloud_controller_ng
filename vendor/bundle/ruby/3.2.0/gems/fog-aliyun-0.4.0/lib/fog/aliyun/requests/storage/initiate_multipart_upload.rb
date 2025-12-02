module Fog
  module Aliyun
    class Storage
      class Real
        # Initiate a multipart upload
        #
        # @param bucket_name [String] Name of bucket to create
        # @param object_name [String] Name of object to create
        # @param options [Hash]
        #
        # @see https://help.aliyun.com/document_detail/31992.html
        #
        def initiate_multipart_upload(bucket_name, object_name, options = {})
          @oss_protocol.initiate_multipart_upload(bucket_name, object_name, options)
        end
      end
    end
  end
end
