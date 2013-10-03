module VCAP::CloudController
  module ServiceBroker::V2

    class ServiceBrokerBadResponse < HttpResponseError
      def initialize(uri, method, response)
        super(
          "The service broker API returned an error from #{uri}: #{response.code} #{response.reason}",
          uri,
          method,
          response
        )
      end
    end

    class ServiceBrokerApiUnreachable < HttpRequestError
      def initialize(uri, method, source)
        super(
          "The service broker API could not be reached: #{uri}",
          uri,
          method,
          source
        )
      end
    end

    class ServiceBrokerApiTimeout < HttpRequestError
      def initialize(uri, method, source)
        super(
          "The service broker API timed out: #{uri}",
          uri,
          method,
          source
        )
      end
    end

    class ServiceBrokerResponseMalformed < HttpResponseError
      def initialize(uri, method, response)
        super(
          "The service broker response was not understood",
          uri,
          method,
          response
        )
      end
    end

    class ServiceBrokerApiAuthenticationFailed < HttpResponseError
      def initialize(uri, method, response)
        super(
          "Authentication failed for the service broker API. Double-check that the token is correct: #{uri}",
          uri,
          method,
          response
        )
      end
    end

    class ServiceBrokerConflict < HttpResponseError
      def initialize(uri, method, response)
        super(
          "Resource already exists: #{uri}",
          uri,
          method,
          response
        )
      end

      def response_code
        409
      end
    end

    class HttpClient

      def initialize(attrs)
        @url = attrs.fetch(:url)
        @auth_username = attrs.fetch(:auth_username)
        @auth_password = attrs.fetch(:auth_password)
      end

      def catalog
        execute(:get, '/v2/catalog')
      end

      # The broker is expected to guarantee uniqueness of the service_instance_id.
      # raises ServiceBrokerConflict if the id is already in use
      def provision(service_instance_id, plan_id, org_guid, space_guid)
        execute(:put, "/v2/service_instances/#{service_instance_id}", {
          plan_id: plan_id,
          organization_guid: org_guid,
          space_guid: space_guid
        })
      end

      def bind(binding_id, service_instance_id)
        execute(:put, "/v2/service_bindings/#{binding_id}", {
          service_instance_id: service_instance_id
        })
      end

      def unbind(binding_id)
        execute(:delete, "/v2/service_bindings/#{binding_id}")
      end

      def deprovision(instance_id)
        execute(:delete, "/v2/service_instances/#{instance_id}")
      end

      private

      attr_reader :url, :auth_username, :auth_password

      # hits the endpoint, json decodes the response
      def execute(method, path, message=nil)
        endpoint = url + path

        headers  = {
          'Content-Type' => 'application/json',
          VCAP::Request::HEADER_NAME => VCAP::Request.current_id
        }

        body = message ? message.to_json : nil

        http = HTTPClient.new
        http.set_auth(endpoint, auth_username, auth_password)

        begin
          response = http.send(method, endpoint, header: headers, body: body)
        rescue SocketError, HTTPClient::ConnectTimeoutError, Errno::ECONNREFUSED => error
          raise ServiceBrokerApiUnreachable.new(endpoint, method, error)
        rescue HTTPClient::KeepAliveDisconnected, HTTPClient::ReceiveTimeoutError => error
          raise ServiceBrokerApiTimeout.new(endpoint, method, error)
        end

        code = response.code.to_i
        case code

        when 204
          return nil # no body

        when 200..299
          begin
            response_hash = Yajl::Parser.parse(response.body)
          rescue Yajl::ParseError
          end

          unless response_hash.is_a?(Hash)
            raise ServiceBrokerResponseMalformed.new(endpoint, method, response)
          end

          return response_hash

        when HTTP::Status::UNAUTHORIZED
          raise ServiceBrokerApiAuthenticationFailed.new(endpoint, method, response)

        when 409
          raise ServiceBrokerConflict.new(endpoint, method, response)

        when 410
          if method == :delete
            logger.warn("Already deleted: #{path}")
            return nil
          end
        end

        raise ServiceBrokerBadResponse.new(endpoint, method, response)
      end

      def logger
        @logger ||= Steno.logger("cc.service_broker.v2.http_client")
      end
    end
  end
end
