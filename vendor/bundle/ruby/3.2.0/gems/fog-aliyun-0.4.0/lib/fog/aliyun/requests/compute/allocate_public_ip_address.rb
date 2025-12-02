# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # Allocate an avalable public IP address to the given instance.
        #
        # ==== Parameters
        # * server_id<~String> - id of the instance
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        #     * 'IpAddress'<~String> - The allocated ip address
        #     * 'RequestId'<~String> - Id of the request
        #
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.201.106.DGkmH7#/pub/ecs/open-api/network&allocatepublicipaddress]
        def allocate_public_ip_address(server_id)
          _action = 'AllocatePublicIpAddress'
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
