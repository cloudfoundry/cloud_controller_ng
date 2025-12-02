# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # Delete a disk By the given id.
        #
        # ==== Parameters
        # * diskId<~String> - the disk_id
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        #     * 'RequestId'<~String> - Id of the request
        #
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.201.106.DGkmH7#/pub/ecs/open-api/disk&deletedisk]
        def delete_disk(diskId)
          action = 'DeleteDisk'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['DiskId'] = diskId
          pathUrl += '&DiskId='
          pathUrl += diskId

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
