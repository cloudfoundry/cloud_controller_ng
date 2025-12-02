module Fog
  module Aliyun
    class Storage
      class Real
        # List information about OSS buckets for authorized user
        #
        def get_service
          @oss_protocol.list_buckets
        end
      end
    end
  end
end
