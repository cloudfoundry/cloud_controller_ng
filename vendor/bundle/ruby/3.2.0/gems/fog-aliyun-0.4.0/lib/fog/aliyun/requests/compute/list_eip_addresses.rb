# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/network&describeeipaddress]
        def list_eip_addresses(options = {})
          _action = 'DescribeEipAddresses'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _pathURL = defaultAliyunUri(_action, _sigNonce, _time)

          _Status = options[:state]
          if _Status
            _parameters['Status'] = _Status
            _pathURL += '&Status=' + _Status
          end

          _EipAddress = options[:ip_address]
          if _EipAddress
            _parameters['EipAddress'] = _EipAddress
            _pathURL += '&EipAddress=' + _EipAddress
          end

          _AllocationId = options[:allocation_id]
          if _AllocationId
            _parameters['AllocationId'] = _AllocationId
            _pathURL += '&AllocationId=' + _AllocationId
          end

          _PageNumber = options[:page_number]
          if _PageNumber
            _parameters['PageNumber'] = _PageNumber
            _pathURL += '&PageNumber=' + _PageNumber
          end

          _PageSize = options[:page_size]
          _PageSize ||= '50'
          _parameters['PageSize'] = _PageSize
          _pathURL += '&PageSize=' + _PageSize

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
