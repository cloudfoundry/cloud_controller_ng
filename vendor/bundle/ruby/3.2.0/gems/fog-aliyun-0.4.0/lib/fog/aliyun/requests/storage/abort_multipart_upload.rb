
module Fog
  module Aliyun
    class Storage
      class Real
        #
        # Abort a multipart upload
        #
        # @param [String] bucket_name Name of bucket to abort multipart upload on
        # @param [String] object_name Name of object to abort multipart upload on
        # @param [String] upload_id Id of upload to add part to
        #
        # @see https://help.aliyun.com/document_detail/31996.html
        #
        def abort_multipart_upload(bucket_name, object_name, upload_id)
          @oss_protocol.abort_multipart_upload(bucket_name, object_name, upload_id)
        end
      end

    end
  end
end
