require 'httpclient'

module VCAP::Services
  module ServiceBrokers::V2
    module IdentityEncoder
      def self.encode(user_guid)
        "cloudfoundry #{Base64.strict_encode64({ user_id: user_guid }.to_json)}"
      end
    end

    class HttpClient
      attr_reader :url

      def initialize(attrs, logger=nil)
        @url = attrs.fetch(:url)
        @auth_username = attrs.fetch(:auth_username)
        @auth_password = attrs.fetch(:auth_password)
        @broker_client_timeout = VCAP::CloudController::Config.config.get(:broker_client_timeout_seconds)
        @logger = logger || Steno.logger('cc.service_broker.v2.http_client')
      end

      def get(path, user_guid: nil)
        make_request(:get, uri_for(path), nil, user_guid: user_guid)
      end

      def put(path, message, user_guid: nil)
        make_request(:put, uri_for(path), message.to_json, content_type: 'application/json', user_guid: user_guid)
      end

      def patch(path, message, user_guid: nil)
        make_request(:patch, uri_for(path), message.to_json, content_type: 'application/json', user_guid: user_guid)
      end

      def delete(path, message, user_guid: nil)
        uri = uri_for(path)
        uri.query = message.to_query

        make_request(:delete, uri, nil, user_guid: user_guid)
      end

      private

      attr_reader :auth_username, :auth_password, :broker_client_timeout, :extra_path, :logger

      def uri_for(path)
        URI(url + path)
      end

      def make_request(method, uri, body=nil, options={})
        client = HTTPClient.new(force_basic_auth: true)
        client.set_auth(nil, auth_username, auth_password)
        client.ssl_config.set_default_paths

        client.ssl_config.verify_mode = verify_certs? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        client.connect_timeout = broker_client_timeout
        client.receive_timeout = broker_client_timeout
        client.send_timeout = broker_client_timeout

        opts = { body: body, header: {}, follow_redirect: true }

        client.default_header = default_headers
        opts[:header]['Content-Type'] = options[:content_type] if options[:content_type]

        user_guid = user_guid(options)
        opts[:header][VCAP::Request::HEADER_BROKER_API_ORIGINATING_IDENTITY] = IdentityEncoder.encode(user_guid) if user_guid

        opts[:header][VCAP::Request::HEADER_ZIPKIN_B3_TRACEID] = VCAP::Request.b3_trace_id if VCAP::Request.b3_trace_id
        opts[:header][VCAP::Request::HEADER_ZIPKIN_B3_SPANID] = VCAP::Request.b3_span_id if VCAP::Request.b3_span_id

        headers = client.default_header.merge(opts[:header])

        logger.debug "Sending #{method} to #{uri}, BODY: #{body.inspect}, HEADERS: #{headers}"

        response = client.request(method, uri, opts)
        logger.debug "Response from request to #{uri}: STATUS #{response.code}, BODY: #{redact_credentials(response)}, HEADERS: #{response.headers.inspect}"

        HttpResponse.from_http_client_response(response)
      rescue SocketError, Errno::ECONNREFUSED => error
        raise Errors::ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
      rescue HTTPClient::TimeoutError => error
        raise Errors::HttpClientTimeout.new(uri.to_s, method, error)
      rescue => error
        raise HttpRequestError.new(error.message, uri.to_s, method, error)
      end

      def redact_credentials(response)
        body = MultiJson.load(response.body)
        body['credentials'] = VCAP::CloudController::Presenters::Censorship::REDACTED if body['credentials']
        body.inspect
      rescue
        'Error parsing body'
      end

      def default_headers
        {
          VCAP::Request::HEADER_BROKER_API_VERSION => VCAP::CloudController::Constants::OSBAPI_VERSION,
          VCAP::Request::HEADER_NAME => VCAP::Request.current_id,
          VCAP::Request::HEADER_BROKER_API_REQUEST_IDENTITY => SecureRandom.uuid,
          'Accept' => 'application/json',
          VCAP::Request::HEADER_API_INFO_LOCATION => "#{VCAP::CloudController::Config.config.get(:external_domain)}/v2/info"
        }
      end

      def verify_certs?
        !VCAP::CloudController::Config.config.get(:skip_cert_verify)
      end

      def user_guid(options)
        options[:user_guid] || VCAP::CloudController::SecurityContext.current_user_guid
      end
    end
  end
end
