module VCAP::Services::ServiceBrokers::V2
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
      511 => 'Network Authentication Required'
    }.freeze

    HEADER_RETRY_AFTER = 'Retry-After'.freeze

    def initialize(attrs={})
      @code = attrs.fetch(:code)
      @message = attrs[:message] || STATUS_CODE_MESSAGES[@code]
      @body = attrs.fetch(:body)
      initialize_case_insensitive_headers(attrs[:headers])
    end

    def self.from_http_client_response(http_client_response)
      @http_client_response = http_client_response
      self.new(
        code: http_client_response.code,
        message: STATUS_CODE_MESSAGES.fetch(http_client_response.code, http_client_response.reason),
        body: http_client_response.body,
        headers: http_client_response.headers,
      )
    end

    def [](key)
      @headers[key.downcase]
    end

    private

    def initialize_case_insensitive_headers(original_headers)
      @headers = {}

      return unless original_headers

      original_headers.each do |key, value|
        @headers[key.downcase] = value
      end
    end
  end
end
