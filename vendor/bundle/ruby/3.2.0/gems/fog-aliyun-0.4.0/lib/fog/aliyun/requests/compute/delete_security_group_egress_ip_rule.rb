# frozen_string_literal: true

require 'addressable'

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/securitygroup&authorizesecuritygroup]
        def delete_security_group_egress_ip_rule(securitygroup_id, destCidrIp, nicType, option = {})
          action = 'RevokeSecurityGroupEgress'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['SecurityGroupId'] = securitygroup_id
          pathUrl += '&SecurityGroupId='
          pathUrl += securitygroup_id

          parameters['DestCidrIp'] = destCidrIp
          pathUrl += '&DestCidrIp='
          pathUrl += Addressable::URI.encode_component(destCidrIp, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          nicType ||= 'intranet'
          parameters['NicType'] = nicType
          pathUrl += '&NicType='
          pathUrl += nicType

          portRange = option[:portRange]
          portRange ||= '-1/-1'
          parameters['PortRange'] = portRange
          pathUrl += '&PortRange='
          pathUrl += Addressable::URI.encode_component(portRange, Addressable::URI::CharacterClasses::UNRESERVED + '|')

          protocol = option[:protocol]
          protocol ||= 'all'
          parameters['IpProtocol'] = protocol
          pathUrl += '&IpProtocol='
          pathUrl += protocol

          policy = option[:policy]
          policy ||= 'accept'
          parameters['Policy'] = policy
          pathUrl += '&Policy='
          pathUrl += policy

          priority = option[:priority]
          priority ||= '1'
          parameters['Priority'] = priority
          pathUrl += '&Priority='
          pathUrl += priority

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
