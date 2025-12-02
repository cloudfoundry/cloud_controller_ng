# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        def create_vpn_customergateway(ipaddress, options = {})
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&createvswitch]
          action = 'CreateCustomerGateway'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defalutVPCParameters(action, sigNonce, time)
          pathUrl = defaultAliyunVPCUri(action, sigNonce, time)

          parameters['IpAddress'] = ipaddress
          pathUrl += '&IpAddress='
          pathUrl += ipaddress

          name = options[:name]
          desc = options[:description]

          if name
            parameters['Name'] = name
            pathUrl += '&Name='
            pathUrl += name
          end

          if desc
            parameters['Description'] = desc
            pathUrl += '&Description='
            pathUrl += desc
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
