# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&describevswitches]
        def list_vswitchs(vpcid, options = {})
          action = 'DescribeVSwitches'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['VpcId'] = vpcid
          pathUrl += '&VpcId='
          pathUrl += vpcid

          pageNumber = options[:pageNumber]
          pageSize = options[:pageSize]
          vswitchId = options[:vSwitchId]
          if vswitchId
            parameters['VSwitchId'] = vswitchId
            pathUrl += '&VSwitchId='
            pathUrl += vswitchId
          end
          if pageNumber
            parameters['PageNumber'] = pageNumber
            pathUrl += '&PageNumber='
            pathUrl += pageNumber
          end

          pageSize ||= '50'
          parameters['PageSize'] = pageSize
          pathUrl += '&PageSize='
          pathUrl += pageSize

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
