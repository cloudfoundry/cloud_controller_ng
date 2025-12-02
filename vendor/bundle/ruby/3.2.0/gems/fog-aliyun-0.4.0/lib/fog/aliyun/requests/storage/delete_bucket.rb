# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        # Delete an existing bucket
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket to delete
        #
        def delete_bucket(bucket_name)
          @oss_protocol.delete_bucket(bucket_name)
        end
      end
    end
  end
end
