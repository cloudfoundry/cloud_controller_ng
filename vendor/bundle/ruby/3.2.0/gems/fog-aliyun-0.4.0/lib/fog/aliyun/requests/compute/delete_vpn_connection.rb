# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        def delete_vpn_connection(vpn_connectionid)
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&deletevswitch]
          action = 'DeleteVpnConnection'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defalutVPCParameters(action, sigNonce, time)
          pathUrl = defaultAliyunVPCUri(action, sigNonce, time)

          if vpn_connectionid
            parameters['VpnConnectionId'] = vpn_connectionid
            pathUrl += '&VpnConnectionId='
            pathUrl += vpn_connectionid
          else
            raise ArgumentError, 'Missing required vpn_connectionid'
          end

          signature = sign(@aliyun_accesskey_secret, parameters)
          pathUrl += '&Signature='
          pathUrl += signature

          VPCrequest(
            expects: [200, 203],
            method: 'GET',
            path: pathUrl
          )
        end
      end
    end
  end
end
