# frozen_string_literal: true

module Fog
  module Compute
    class Aliyun
      class Real
        # {Aliyun API Reference}[https://docs.aliyun.com/?spm=5176.100054.3.1.DGkmH7#/pub/ecs/open-api/instance&describeinstances]
        def list_servers(options = {})
          _action = 'DescribeInstances'
          _sigNonce = randonStr
          _time = Time.new.utc

          _parameters = defaultParameters(_action, _sigNonce, _time)
          _query_parameters = defaultAliyunQueryParameters(_action, _sigNonce, _time)

          _InstanceId = options[:instanceId]
          _VpcId = options[:vpcId]
          _SecurityGroupId = options[:securityGroupId]
          _PageNumber = options[:pageNumber]
          _PageSize = options[:pageSize]

          unless _InstanceId.nil?
            _InstanceStr = "[\"#{_InstanceId}\"]"
            _parameters['InstanceIds'] = _InstanceStr
            _query_parameters[:InstanceIds] = _InstanceStr
          end

          unless _VpcId.nil?
            _parameters['VpcId'] = _VpcId
            _query_parameters[:VpcId] = _VpcId
          end

          unless _SecurityGroupId.nil?
            _parameters['SecurityGroupId'] = _SecurityGroupId
            _query_parameters[:SecurityGroupId] = _SecurityGroupId
          end

          unless _PageNumber.nil?
            _parameters['PageNumber'] = _PageNumber
            _query_parameters[:PageNumber] = _PageNumber
          end

          _PageSize ||= '50'
          _parameters['PageSize'] = _PageSize
          _query_parameters[:PageSize] = _PageSize

          _signature = sign_without_encoding(@aliyun_accesskey_secret, _parameters)
          _query_parameters[:Signature] = _signature

          request(
            expects: [200, 203],
            method: 'GET',
            query: _query_parameters
          )
        end
      end

      class Mock
        def list_servers(_options = {})
          response = Excon::Response.new
          data = list_servers_detail.body['servers']
          servers = []
          for server in data
            servers << server.select { |key, _value| %w[id name links].include?(key) }
          end
          response.status = [200, 203][rand(1)]
          response.body = { 'servers' => servers }
          response
        end
      end
    end
  end
end
