# frozen_string_literal: true

require 'addressable'

module Fog
  module Compute
    class Aliyun
      class Real
        def create_vswitch(vpcId, cidrBlock, options = {})
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&createvswitch]
          action = 'CreateVSwitch'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['VpcId'] = vpcId
          pathUrl += '&VpcId='
          pathUrl += vpcId

          parameters['CidrBlock'] = cidrBlock
          pathUrl += '&CidrBlock='
          pathUrl += Addressable::URI.encode_component(cidrBlock, Addressable::URI::CharacterClasses::UNRESERVED + '|')

          parameters['ZoneId'] = @aliyun_zone_id
          pathUrl += '&ZoneId='
          pathUrl += @aliyun_zone_id

          name = options[:name]
          desc = options[:description]

          if name
            parameters['VSwitchName'] = name
            pathUrl += '&VSwitchName='
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
