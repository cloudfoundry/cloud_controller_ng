# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # Allocate an eip IP address.
        #
        # ==== Notes
        # The new eip Ip address would be avalable
        # The allocated eip Ip address can only associate to the instance of the vpc in the same region
        # Now the eip can support ICMP,TCP,UDP
        # ==== Parameters
        # * server_id<~String> - id of the instance
        # * allocationId<~String> - id of the EIP
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        #     * 'EipAddress'<~String> - the allocated eip address
        #     * 'AllocationId'<~String> - the instance id on the public ip
        #     * 'RequestId'<~String> - Id of the request
        #
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.201.106.DGkmH7#/pub/ecs/open-api/network&allocateeipaddress]
        def allocate_eip_address(options = {})
          _action = 'AllocateEipAddress'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _pathURL = defaultAliyunUri(_action, _sigNonce, _time)

          # optional parameters
          _Bandwidth = options[:bandwidth]
          if _Bandwidth
            _parameters['Bandwidth'] = _Bandwidth
            _pathURL += '&Bandwidth=' + _Bandwidth
          end

          _InternetChargeType = options[:internet_charge_type]
          _InternetChargeType ||= 'PayByTraffic'
          _parameters['InternetChargeType'] = _InternetChargeType
          _pathURL += '&InternetChargeType=' + _InternetChargeType

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
