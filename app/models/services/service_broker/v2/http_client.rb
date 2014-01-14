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

      attr_reader :url

      def initialize(attrs)
        @url = attrs.fetch(:url)
        @auth_username = attrs.fetch(:auth_username)
        @auth_password = attrs.fetch(:auth_password)
        @broker_client_timeout = VCAP::CloudController::Config.config[:broker_client_timeout_seconds] || 60
      end

      def get(path)
        make_request(:get, path, nil, nil)
      end

      def put(path, message)
        make_request(:put, path, message.to_json, 'application/json')
      end

      def delete(path, message)
        uri = uri_for(path)
        uri.query = message.to_query

        make_request(:delete, uri.request_uri, nil, nil)
      end

      private

      attr_reader :auth_username, :auth_password, :broker_client_timeout

      def uri_for(path)
        URI(url + path)
      end

      def make_request(method, path_with_query, body, content_type)
        uri = uri_for(path_with_query)
        begin
          req_class = method.to_s.capitalize
          req = Net::HTTP.const_get(req_class).new(uri.request_uri)
          req.basic_auth(auth_username, auth_password)
          req.body = body
          req.content_type = content_type if content_type
          req[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
          req[VCAP::Request::HEADER_BROKER_API_VERSION] = '2.1'
          req['Accept'] = 'application/json'

          logger.debug "Sending #{req_class} to #{uri}, BODY: #{req.body.inspect}, HEADERS: #{req.to_hash.inspect}"

          use_ssl = uri.scheme.to_s.downcase == 'https'
          response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl=> use_ssl) do |http|
            http.open_timeout = broker_client_timeout
            http.read_timeout = broker_client_timeout

            http.request(req)
          end

          logger.debug "Response from request to #{uri}: STATUS #{response.code}, BODY: #{response.body.inspect}, HEADERS: #{response.to_hash.inspect}"
          return response
        rescue SocketError, Errno::ECONNREFUSED => error
          raise ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
        rescue Timeout::Error => error
          raise ServiceBrokerApiTimeout.new(uri.to_s, method, error)
        rescue => error
          raise HttpRequestError.new(error.message, uri.to_s, method, error)
        end
      end

      def logger
        @logger ||= Steno.logger('cc.service_broker.v2.http_client')
      end
    end
  end
end
