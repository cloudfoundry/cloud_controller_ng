# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        def put_bucket(bucket_name, options = {})
          @oss_protocol.create_bucket(bucket_name, options)
        end
      end
    end
  end
end
