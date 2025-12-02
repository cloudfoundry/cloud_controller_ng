
module Fog
  module Aliyun
    class Storage
      class Real
        # Upload a part for a multipart upload
        #
        # @param bucket_name [String] Name of bucket to add part to
        # @param object_name [String] Name of object to add part to
        # @param upload_id [String] Id of upload to add part to
        # @param part_number [String] Index of part in upload
        # @param data [File||String] Content for part
        #
        # @see https://help.aliyun.com/document_detail/31993.html
        #
        def upload_part(bucket_name, object_name, upload_id, part_number, data)
          @oss_protocol.upload_part(bucket_name, object_name, upload_id, part_number) do |sw|
              sw.write(data)
          end
        end
      end
    end
  end
end
