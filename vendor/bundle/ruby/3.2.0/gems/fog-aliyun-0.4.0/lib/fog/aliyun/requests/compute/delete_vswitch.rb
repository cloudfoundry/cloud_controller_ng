# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        def delete_vswitch(vswitch_id)
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&deletevswitch]
          action = 'DeleteVSwitch'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          if vswitch_id
            parameters['VSwitchId'] = vswitch_id
            pathUrl += '&VSwitchId='
            pathUrl += vswitch_id
          else
            raise ArgumentError, 'Missing required vswitch_id'
          end

          signature = sign(@aliyun_accesskey_secret, parameters)
          pathUrl += '&Signature='
          pathUrl += signature

          request(
            expects: [200, 203],
            method: 'GET',
            path: pathUrl
          )
        end
      end
    end
  end
end
