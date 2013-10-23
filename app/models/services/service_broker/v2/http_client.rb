require 'net/http'

module VCAP::CloudController
  module ServiceBroker::V2

    class ServiceBrokerBadResponse < HttpResponseError
      def initialize(uri, method, response)
        begin
          hash = Yajl::Parser.parse(response.body)
        rescue Yajl::ParseError
        end

        if hash.is_a?(Hash) && hash.has_key?('description')
          message = "Service broker error: #{hash['description']}"
        else
          message = "The service broker API returned an error from #{uri}: #{response.code} #{response.message}"
        end

        super(message, uri, method, response)
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
          "Authentication failed for the service broker API. Double-check that the username and password are correct: #{uri}",
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

      # The broker is expected to guarantee uniqueness of instance_id.
      # raises ServiceBrokerConflict if the id is already in use
      def provision(params)
        instance_id = params.fetch(:instance_id)
        plan_id = params.fetch(:plan_id)
        service_id = params.fetch(:service_id)
        org_guid = params.fetch(:org_guid)
        space_guid = params.fetch(:space_guid)

        execute(:put, "/v2/service_instances/#{instance_id}", {
          service_id: service_id,
          plan_id: plan_id,
          organization_guid: org_guid,
          space_guid: space_guid,
        })
      end

      def bind(params)
        binding_id = params.fetch(:binding_id)
        instance_id = params.fetch(:instance_id)
        plan_id = params.fetch(:plan_id)
        service_id = params.fetch(:service_id)

        execute(:put, "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}", {
          plan_id: plan_id,
          service_id: service_id,
        })
      end

      def unbind(params)
        binding_id = params.fetch(:binding_id)
        instance_id = params.fetch(:instance_id)
        plan_id = params.fetch(:plan_id)
        service_id = params.fetch(:service_id)

        execute(:delete, "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}", {
          plan_id: plan_id,
          service_id: service_id,
        })
      end

      def deprovision(instance_id)
        execute(:delete, "/v2/service_instances/#{instance_id}")
      end

      private

      attr_reader :url, :auth_username, :auth_password

      # hits the endpoint, json decodes the response
      def execute(method, path, message=nil)
        endpoint = url + path
        uri = URI(endpoint)

        case method
          when :put
            response = make_request(method, uri, message.to_json)
          when :get, :delete
            uri.query = message.to_query if message
            response = make_request(method, uri, nil)
          else
            raise ArgumentError.new("Don't know how to handle method: #{method.inspect}")
        end

        parse_response(method, uri, response)
      end

      def make_request(method, uri, body)
        begin
          req_class = method.to_s.capitalize
          req = Net::HTTP.const_get(req_class).new(uri.request_uri)
          req.basic_auth(auth_username, auth_password)
          req.body = body
          req.content_type = 'application/json'
          req[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
          req['Accept'] = 'application/json'

          response = Net::HTTP.start(uri.hostname, uri.port) do |http|
            # TODO: make this configurable?
            http.open_timeout = 60
            http.read_timeout = 60

            http.request(req)
          end
        rescue SocketError, Errno::ECONNREFUSED => error
          raise ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
        rescue Timeout::Error => error
          raise ServiceBrokerApiTimeout.new(uri.to_s, method, error)
        rescue => error
          raise HttpRequestError.new(error.message, uri.to_s, method, error)
        end
      end

      def parse_response(method, uri, response)
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
              raise ServiceBrokerResponseMalformed.new(uri.to_s, method, response)
            end

            return response_hash

          when HTTP::Status::UNAUTHORIZED
            raise ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)

          when 409
            raise ServiceBrokerConflict.new(uri.to_s, method, response)

          when 410
            if method == :delete
              logger.warn("Already deleted: #{uri.to_s}")
              return nil
            end
        end

        raise ServiceBrokerBadResponse.new(uri.to_s, method, response)
      end

      def logger
        @logger ||= Steno.logger("cc.service_broker.v2.http_client")
      end
    end
  end
end
