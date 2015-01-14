require 'httpclient'

module VCAP::Services
  module ServiceBrokers::V2
    class HttpResponse
      def initialize(http_client_response)
        @http_client_response = http_client_response
      end

      def code
        @http_client_response.code
      end

      def message
        @http_client_response.reason
      end

      def body
        @http_client_response.body
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

      def patch(path, message)
        make_request(:patch, uri_for(path), message.to_json, 'application/json')
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
        client = HTTPClient.new(force_basic_auth: true)
        client.set_auth(uri, auth_username, auth_password)

        client.default_header[VCAP::Request::HEADER_BROKER_API_VERSION] = '2.4'
        client.default_header[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
        client.default_header['Accept'] = 'application/json'

        client.ssl_config.verify_mode = verify_certs? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        client.connect_timeout = broker_client_timeout
        client.receive_timeout = broker_client_timeout
        client.send_timeout = broker_client_timeout

        opts = { body: body }
        opts[:header] = { 'Content-Type' => content_type } if content_type

        headers = client.default_header.merge(opts[:header]) if opts[:header]
        logger.debug "Sending #{method} to #{uri}, BODY: #{body.inspect}, HEADERS: #{headers}"

        response = client.request(method, uri, opts)

        logger.debug "Response from request to #{uri}: STATUS #{response.code}, BODY: #{response.body.inspect}, HEADERS: #{response.headers.inspect}"

        HttpResponse.new(response)
      rescue SocketError, Errno::ECONNREFUSED => error
        raise Errors::ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
      rescue HTTPClient::TimeoutError => error
        raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, error)
      rescue => error
        raise HttpRequestError.new(error.message, uri.to_s, method, error)
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
