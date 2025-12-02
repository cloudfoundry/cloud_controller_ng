# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vpc&describevpcs]
        def list_vrouters(options = {})
          action = 'DescribeVrouters'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          _VRouterId = options[:vRouterId]
          if _VRouterId
            parameters['VRouterId'] = _VRouterId
            pathUrl += '&VRouterId='
            pathUrl += _VRouterId
          end

          pageNumber = options[:pageNumber]
          pageSize = options[:pageSize]
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

      class Mock
        def list_vrouters
          response = Excon::Response.new
          data = list_images_detail.body['VRouters']
          images = []
          for image in data
            images << image.select { |key, _value| %w[id name links].include?(key) }
          end
          response.status = [200, 203][rand(1)]
          response.body = { 'VRouter' => images }
          response
        end
      end
    end
  end
end
