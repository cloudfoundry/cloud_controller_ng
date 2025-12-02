# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        def delete_snapshot(snapshotId)
          # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/snapshot&deletesnapshot]
          action = 'DeleteSnapshot'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['SnapshotId'] = snapshotId
          pathUrl += '&SnapshotId='
          pathUrl += snapshotId

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
