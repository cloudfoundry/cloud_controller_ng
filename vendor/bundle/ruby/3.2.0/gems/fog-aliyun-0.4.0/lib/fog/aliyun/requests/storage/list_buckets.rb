# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        def list_buckets(options = {})
          maxKeys = options[:max_keys] || 1000
          maxKeys = maxKeys.to_i
          maxKeys = [maxKeys, 1000].min

          options[:limit] = maxKeys
          options.delete(:max_keys)
          @oss_protocol.list_buckets(options)
        end
      end
    end
  end
end
