# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        def list_objects(bucket_name, options = {})
          maxKeys = options[:max_keys] || 1000
          maxKeys = maxKeys.to_i
          maxKeys = [maxKeys, 1000].min

          options[:limit] = maxKeys
          options.delete(:max_keys)
          @oss_protocol.list_objects(bucket_name, options)
        end

        def list_multipart_uploads(bucket_name, _options = {})
          @oss_protocol.list_multipart_uploads(bucket_name, _options)
        end

        def list_parts(bucket_name, object_name, upload_id, _options = {})
          @oss_protocol.list_parts(bucket_name, object_name, upload_id, _options)
        end
      end
    end
  end
end
