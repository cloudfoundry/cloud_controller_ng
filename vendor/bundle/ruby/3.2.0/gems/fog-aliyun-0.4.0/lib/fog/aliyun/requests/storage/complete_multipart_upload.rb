
module Fog
  module Aliyun
    class Storage
      class Real
        # Complete a multipart upload
        #
        # @param [String] bucket_name Name of bucket to complete multipart upload for
        # @param [String] object_name Name of object to complete multipart upload for
        # @param [String] upload_id Id of upload to add part to
        # @param [Array] parts Array of etag and number as Strings for parts
        #
        # @see https://help.aliyun.com/document_detail/31995.html
        #
        def complete_multipart_upload(bucket_name, object_name, upload_id, parts)
          @oss_protocol.complete_multipart_upload(bucket_name, object_name, upload_id, parts)
        end
      end
    end
  end
end
