# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        def create_vpn_connection(customergatewayId, vpngatewayId, localsubnet, remotesubnet, options = {})
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&createvswitch]
          action = 'CreateVpnConnection'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defalutVPCParameters(action, sigNonce, time)
          pathUrl = defaultAliyunVPCUri(action, sigNonce, time)

          parameters['CustomerGatewayId'] = customergatewayId
          pathUrl += '&CustomerGatewayId='
          pathUrl += customergatewayId

          parameters['VpnGatewayId'] = vpngatewayId
          pathUrl += '&VpnGatewayId='
          pathUrl += vpngatewayId

          parameters['LocalSubnet'] = localsubnet
          pathUrl += '&LocalSubnet='
          pathUrl += localsubnet

          parameters['RemoteSubnet'] = remotesubnet
          pathUrl += '&RemoteSubnet='
          pathUrl += remotesubnet

          name = options[:name]
          ipsecconfig = options[:ipsecconfig]

          if name
            parameters['Name'] = name
            pathUrl += '&Name='
            pathUrl += name
          end

          if ipsecconfig
            parameters['IpsecConfig'] = ipsecconfig
            pathUrl += '&IpsecConfig='
            pathUrl += ipsecconfig
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
