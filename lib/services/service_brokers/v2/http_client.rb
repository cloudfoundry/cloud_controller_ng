require 'httpclient'

module VCAP::Services
  module ServiceBrokers::V2
    class HttpResponse
      attr_reader :code, :message, :body

      STATUS_CODE_MESSAGES = {
        100 => 'Continue',
        101 => 'Switching Protocols',
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        307 => 'Temporary Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Long',
        415 => 'Unsupported Media Type',
        416 => 'Requested Range Not Satisfiable',
        417 => 'Expectation Failed',
        418 => "I'm a Teapot",
        422 => 'Unprocessable Entity',
        423 => 'Locked',
        424 => 'Failed Dependency',
        428 => 'Precondition Required',
        429 => 'Too Many Requests',
        431 => 'Request Header Fields Too Large',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported',
        507 => 'Insufficient Storage',
        508 => 'Loop Detected',
        511 => 'Network Authentication Required',
      }.freeze

      def initialize(attrs={})
        @code = attrs.fetch(:code)
        @message = attrs[:message] || STATUS_CODE_MESSAGES[@code]
        @body = attrs.fetch(:body)
      end

      def self.from_http_client_response(http_client_response)
        @http_client_response = http_client_response
        self.new(
          code: http_client_response.code,
          message: STATUS_CODE_MESSAGES.fetch(http_client_response.code, http_client_response.reason),
          body: http_client_response.body,
        )
      end
    end

    class HttpClient
      attr_reader :url

      def initialize(attrs, logger=nil)
        @url = attrs.fetch(:url)
        @auth_username = attrs.fetch(:auth_username)
        @auth_password = attrs.fetch(:auth_password)
        @broker_client_timeout = VCAP::CloudController::Config.config[:broker_client_timeout_seconds] || 60
        @logger = logger || Steno.logger('cc.service_broker.v2.http_client')
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

      attr_reader :auth_username, :auth_password, :broker_client_timeout, :extra_path, :logger

      def uri_for(path)
        URI(url + path)
      end

      def make_request(method, uri, body, content_type)
        client = HTTPClient.new(force_basic_auth: true)
        client.set_auth(uri, auth_username, auth_password)
        client.ssl_config.set_default_paths

        client.ssl_config.verify_mode = verify_certs? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        client.connect_timeout = broker_client_timeout
        client.receive_timeout = broker_client_timeout
        client.send_timeout = broker_client_timeout

        opts = { body: body, header: {} }

        client.default_header = default_headers
        opts[:header]['Content-Type'] = content_type if content_type

        user_guid = VCAP::CloudController::SecurityContext.current_user_guid
        opts[:header][VCAP::Request::HEADER_BROKER_API_ORIGINATING_IDENTITY] = originating_identity(user_guid) if user_guid
        headers = default_headers.merge(opts[:header])

        logger.debug "Sending #{method} to #{uri}, BODY: #{body.inspect}, HEADERS: #{headers}"

        response = client.request(method, uri, opts)
        logger.debug "Response from request to #{uri}: STATUS #{response.code}, BODY: #{redact_credentials(response)}, HEADERS: #{response.headers.inspect}"

        HttpResponse.from_http_client_response(response)
      rescue SocketError, Errno::ECONNREFUSED => error
        raise Errors::ServiceBrokerApiUnreachable.new(uri.to_s, method, error)
      rescue HTTPClient::TimeoutError => error
        raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, error)
      rescue => error
        raise HttpRequestError.new(error.message, uri.to_s, method, error)
      end

      def redact_credentials(response)
        body = MultiJson.load(response.body)
        body['credentials'] = 'REDACTED' if body['credentials']
        body.inspect
      rescue
        'Error parsing body'
      end

      def default_headers
        {
          VCAP::Request::HEADER_BROKER_API_VERSION => '2.12',
          VCAP::Request::HEADER_NAME => VCAP::Request.current_id,
          'Accept' => 'application/json',
          VCAP::Request::HEADER_API_INFO_LOCATION => "#{VCAP::CloudController::Config.config[:external_domain]}/v2/info"
        }
      end

      def originating_identity(user_guid)
        "cloudfoundry #{Base64.strict_encode64({ user_id: user_guid }.to_json)}"
      end

      def verify_certs?
        !VCAP::CloudController::Config.config[:skip_cert_verify]
      end
    end
  end
end
