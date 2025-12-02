# frozen_string_literal: true

require 'addressable'

module Fog
  module Aliyun
    class Storage
      class Real
        # Get an expiring object http url
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket
        # * object_name<~String> - Name of object to get expiring url for
        # * expires<~Integer> - An expiry time for this url
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~String> - url for object
        def get_object_http_url_public(bucket_name, object_name, expires)
          bucket = @oss_client.get_bucket(bucket_name)
          acl = bucket.acl()

          if acl == 'private'
            expires_time = (Time.now.to_i + (expires.nil? ? 0 : expires.to_i)).to_s
            resource = bucket_name + '/' + object_name
            signature = sign('GET', expires_time, nil, resource)
            'http://' + bucket_name + '.' + @host + '/' + object_name +
              '?OSSAccessKeyId=' + @aliyun_accesskey_id + '&Expires=' + expires_time +
              '&Signature=' + Addressable::URI.encode_component(signature, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          elsif acl == 'public-read' || acl == 'public-read-write'
            'http://' + bucket_name + '.' + @host + '/' + object_name
          else
            'acl is wrong with value:' + acl
          end
        end
      end
    end
  end
end
