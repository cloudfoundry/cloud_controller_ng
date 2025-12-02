# frozen_string_literal: true

require 'addressable'

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/disk&detachdisk]
        def detach_disk(instanceId, diskId, _options = {})
          action = 'DetachDisk'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['InstanceId'] = instanceId
          pathUrl += '&InstanceId='
          pathUrl += instanceId

          parameters['DiskId'] = diskId
          pathUrl += '&DiskId='
          pathUrl += diskId

          device = _options[:device]
          if device
            parameters['Device'] = device
            pathUrl += '&Device='
            pathUrl += Addressable::URI.encode_component(device, Addressable::URI::CharacterClasses::UNRESERVED + '|')
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
