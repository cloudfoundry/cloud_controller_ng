module VCAP::CloudController
  class ServiceBroker::V2::HttpClient
    def initialize(attrs)
      @url = attrs.fetch(:url)
      @auth_token = attrs.fetch(:auth_token)
    end

    def catalog
      execute(:get, '/v2/catalog')
    end

    # The broker is expected to guarantee uniqueness of the reference_id.
    # raises ServiceBrokerConflict if the reference id is already in use
    def provision(service_id, plan_id, reference_id)
      execute(:post, '/v2/service_instances', {
        service_id: service_id,
        plan_id: plan_id,
        reference_id: reference_id
      })
    end

    def bind(service_instance_id, reference_id)
      execute(:post, "/v2/service_bindings", {
        service_instance_id: service_instance_id,
        reference_id: reference_id
      })
    end

    private

    attr_reader :url, :auth_token

    # hits the endpoint, json decodes the response
    def execute(method, path, message=nil)
      endpoint = url + path

      headers  = {
        'Content-Type' => 'application/json',
        VCAP::Request::HEADER_NAME => VCAP::Request.current_id
      }

      body = message ? message.to_json : nil

      http = HTTPClient.new
      http.set_auth(endpoint, 'cc', auth_token)

      begin
        response = http.send(method, endpoint, header: headers, body: body)
      rescue SocketError, HTTPClient::ConnectTimeoutError, Errno::ECONNREFUSED
        raise VCAP::Errors::ServiceBrokerApiUnreachable.new(endpoint)
      rescue HTTPClient::KeepAliveDisconnected, HTTPClient::ReceiveTimeoutError
        raise VCAP::Errors::ServiceBrokerApiTimeout.new(endpoint)
      end

      code = response.code.to_i
      case code
      when 200..299
        begin
          response_hash = Yajl::Parser.parse(response.body)
        rescue Yajl::ParseError
        end

        unless response_hash.is_a?(Hash)
          raise VCAP::Errors::ServiceBrokerResponseMalformed.new(endpoint)
        end

        return response_hash

      when HTTP::Status::UNAUTHORIZED
        raise VCAP::Errors::ServiceBrokerApiAuthenticationFailed.new(endpoint)
      when 409
        raise VCAP::Errors::ServiceBrokerConflict.new(endpoint)
      else
        raise VCAP::Errors::ServiceBrokerBadResponse.new("#{endpoint}: #{code} #{response.reason}")
      end
    end
  end
end
