# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/vswitch&describevswitches]
        def list_route_tables(vrouterid, options = {})
          action = 'DescribeRouteTables'
          sigNonce = randonStr
          time = Time.new.utc

          parameters = defaultParameters(action, sigNonce, time)
          pathUrl = defaultAliyunUri(action, sigNonce, time)

          parameters['VRouterId'] = vrouterid
          pathUrl += '&VRouterId='
          pathUrl += vrouterid

          pageNumber = options[:pageNumber]
          pageSize = options[:pageSize]
          routeTableId = options[:routeTableId]
          if routeTableId
            parameters['RouteTableId'] = routeTableId
            pathUrl += '&RouteTableId='
            pathUrl += routeTableId
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

      class Mock
        def list_route_tables(_vrouterid, _options = {})
          response = Excon::Response.new
          data = list_images_detail.body['images']
          images = []
          for image in data
            images << image.select { |key, _value| %w[id name links].include?(key) }
          end
          response.status = [200, 203][rand(1)]
          response.body = { 'images' => images }
          response
        end
      end
    end
  end
end
