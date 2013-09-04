require 'net/http'
require 'uri'

module VCAP::CloudController
  class ServiceBrokerClient

    def initialize(endpoint_base, token)
      @endpoint_base = endpoint_base
      @token = token
    end


    # Provision a service with the reference_id. The broker is expected to
    # guarantee uniqueness of the reference_id.
    # TODO: what does it do when it's not unique?
    def provision(service_id, plan_id, reference_id)
      execute(:post, '/v2/service_instances', {
        service_id: service_id,
        plan_id: plan_id,
        reference_id: reference_id
      })
    end

    def catalog
      execute(:get, '/v2/catalog')
    end

    private

    attr_reader :endpoint_base, :token

    # hits the endpoint, json decodes the response
    def execute(method, path, message=nil)
      endpoint = endpoint_base + path

      headers  = {
        'Content-Type' => 'application/json',
        VCAP::Request::HEADER_NAME => VCAP::Request.current_id
      }

      body = message ? message.to_json : nil

      http = HTTPClient.new
      http.set_auth(endpoint, 'cc', token)

      begin
        response = http.send(method, endpoint, header: headers, body: body)
      rescue SocketError, HTTPClient::ConnectTimeoutError, Errno::ECONNREFUSED
        raise VCAP::Errors::ServiceBrokerApiUnreachable.new(endpoint)
      rescue HTTPClient::KeepAliveDisconnected, HTTPClient::ReceiveTimeoutError
        raise VCAP::Errors::ServiceBrokerApiTimeout.new(endpoint)
      end

      if response.code.to_i == HTTP::Status::UNAUTHORIZED
        raise VCAP::Errors::ServiceBrokerApiAuthenticationFailed.new(endpoint)
      elsif response.code.to_i != HTTP::Status::OK
        # TODO: this is really not an appropriate response
        raise VCAP::Errors::ServiceBrokerResponseMalformed.new(endpoint)
      else
        begin
          response_hash = Yajl::Parser.parse(response.body)
        rescue Yajl::ParseError
        end

        unless response_hash.is_a?(Hash)
          raise VCAP::Errors::ServiceBrokerResponseMalformed.new(endpoint)
        end

        response_hash
      end
    end
  end
end
