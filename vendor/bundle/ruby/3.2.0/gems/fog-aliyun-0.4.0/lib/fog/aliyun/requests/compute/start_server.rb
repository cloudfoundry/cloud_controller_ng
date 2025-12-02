# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # Start the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be started.
        # === Returns
        # * success <~Boolean>
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/instance&staetinstance]
        def start_server(server_id)
          _action = 'StartInstance'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _pathURL = defaultAliyunUri(_action, _sigNonce, _time)

          _parameters['InstanceId'] = server_id
          _pathURL += '&InstanceId=' + server_id

          _signature = sign(@aliyun_accesskey_secret, _parameters)
          _pathURL += '&Signature=' + _signature

          request(
            expects: [200, 204],
            method: 'GET',
            path: _pathURL
          )
        end
      end
    end
  end
end
