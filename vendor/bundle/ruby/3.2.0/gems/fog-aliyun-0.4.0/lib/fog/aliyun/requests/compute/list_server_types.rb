# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/other&describeinstancetypes]
        def list_server_types
          _action = 'DescribeInstanceTypes'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _pathURL = defaultAliyunUri(_action, _sigNonce, _time)

          _signature = sign(@aliyun_accesskey_secret, _parameters)
          _pathURL += '&Signature=' + _signature

          request(
            expects: [200, 203],
            method: 'GET',
            path: _pathURL
          )
        end

        def get_instance_type(cpuCount, memorySize)
          _action = 'DescribeInstanceTypes'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _pathURL = defaultAliyunUri(_action, _sigNonce, _time)

          _signature = sign(@aliyun_accesskey_secret, _parameters)
          _pathURL += '&Signature=' + _signature

          response = request(
            expects: [200, 203],
            method: 'GET',
            path: _pathURL
          )

          _InstanceTypeId = nil
          _InstanceTypeList = response.body['InstanceTypes']['InstanceType']
          _InstanceTypeList.each do |instance_type|
            next unless (instance_type['CpuCoreCount'] == cpuCount) && (instance_type['MemorySize'] == memorySize)
            _InstanceTypeId = instance_type['InstanceTypeId']
            puts '_instanceTypeId: ' + _InstanceTypeId
            break
          end
          _InstanceTypeId
        end
      end
    end
  end
end
