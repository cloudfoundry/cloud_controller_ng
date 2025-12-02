# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        def bucket_exists?(bucket_name)
          @oss_client.bucket_exists?(bucket_name)
        end

        def get_bucket(bucket_name, options = {})
          unless bucket_name
            raise ArgumentError.new('bucket_name is required')
          end

          # Set the GetBucket max limitation to 1000
          maxKeys = options[:max_keys] || 1000
          maxKeys = maxKeys.to_i
          maxKeys = [maxKeys, 1000].min

          options[:limit] = maxKeys
          options.delete(:max_keys)

          @oss_protocol.list_objects(bucket_name, options)
        end

        def get_bucket_acl(bucket_name)
          @oss_protocol.get_bucket_acl(bucket_name)
        end

        def get_bucket_CORSRules(bucket_name)
          @oss_protocol.get_bucket_cors(bucket_name)
        end

        def get_bucket_lifecycle(bucket_name)
          @oss_protocol.get_bucket_lifecycle(bucket_name)
        end

        def get_bucket_logging(bucket_name)
          @oss_protocol.get_bucket_logging(bucket_name)
        end

        def get_bucket_referer(bucket_name)
          @oss_protocol.get_bucket_referer(bucket_name)
        end

        def get_bucket_website(bucket_name)
          @oss_protocol.get_bucket_website(bucket_name)
        end
      end
    end
  end
end
