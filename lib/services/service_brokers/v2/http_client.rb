require 'net/http'

module VCAP::Services
  module ServiceBrokers::V2

    class ServiceBrokerBadResponse < HttpResponseError
      def initialize(uri, method, response)
        begin
          hash = MultiJson.load(response.body)
        rescue MultiJson::ParseError
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
        error_message = parsed_json(response.body)["description"]

        super(
          error_message || "Resource conflict: #{uri}",
          uri,
          method,
          response
        )
      end

      def response_code
        409
      end

      private

      def parsed_json(str)
        MultiJson.load(str)
      rescue MultiJson::ParseError
        {}
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
        make_request(:get, uri_for(path), nil, nil)
      end

      def put(path, message)
        make_request(:put, uri_for(path), message.to_json, 'application/json')
      end

      def delete(path, message)
        uri = uri_for(path)
        uri.query = message.to_query

        make_request(:delete, uri, nil, nil)
      end

      private

      attr_reader :auth_username, :auth_password, :broker_client_timeout, :extra_path

      def uri_for(path)
        URI(url + path)
      end

      def make_request(method, uri, body, content_type)
        begin
          req = build_request(method, uri, body, content_type)
          opts = build_options(uri)

          response = Net::HTTP.start(uri.hostname, uri.port, opts) do |http|
            http.open_timeout = broker_client_timeout
            http.read_timeout = broker_client_timeout

            http.request(req)
          end

          log_response(uri, response)
          return response
        rescue SocketError, Errno::ECONNREFUSED => error
          raise ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
        rescue Timeout::Error => error
          raise ServiceBrokerApiTimeout.new(uri.to_s, method, error)
        rescue => error
          raise HttpRequestError.new(error.message, uri.to_s, method, error)
        end
      end

      def log_request(uri, req)
        logger.debug "Sending #{req.method} to #{uri}, BODY: #{req.body.inspect}, HEADERS: #{req.to_hash.inspect}"
      end

      def log_response(uri, response)
        logger.debug "Response from request to #{uri}: STATUS #{response.code}, BODY: #{response.body.inspect}, HEADERS: #{response.to_hash.inspect}"
      end

      def build_request(method, uri, body, content_type)
        req_class = method.to_s.capitalize
        req = Net::HTTP.const_get(req_class).new(uri.request_uri)

        req.basic_auth(auth_username, auth_password)

        req[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
        req[VCAP::Request::HEADER_BROKER_API_VERSION] = '2.3'
        req['Accept'] = 'application/json'

        req.body = body
        req.content_type = content_type if content_type

        log_request(uri, req)

        req
      end

      def build_options(uri)
        opts = {}

        use_ssl = uri.scheme.to_s.downcase == 'https'
        opts.merge!(use_ssl: use_ssl)

        verify_mode = verify_certs? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        opts.merge!(verify_mode: verify_mode) if use_ssl
        opts
      end

      def verify_certs?
        !VCAP::CloudController::Config.config[:skip_cert_verify]
      end

      def logger
        @logger ||= Steno.logger('cc.service_broker.v2.http_client')
      end
    end
  end
end
