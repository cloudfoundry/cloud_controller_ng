require 'traffic_controller/traffic_controller'
require 'traffic_controller/errors'
require 'utils/multipart_parser_wrapper'

module TrafficController
  class Client
    BOUNDARY_REGEXP = /boundary=(.+)/.freeze

    def initialize(url:)
      @url = url
    end

    def container_metrics(auth_token:, source_guid:, logcache_filter: nil)
      response = with_request_error_handling do
        client.get("/apps/#{source_guid}/containermetrics", nil, { 'Authorization' => auth_token })
      end

      validate_status!(response: response, statuses: [200])

      envelopes = []
      boundary  = extract_boundary!(response.contenttype)
      parser    = VCAP::MultipartParserWrapper.new(body: response.body, boundary: boundary)
      until (next_part = parser.next_part).nil?
        envelopes << protobuf_decode!(next_part, Models::Envelope)
      end
      envelopes
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue => e
      retry unless (tries -= 1).zero?
      raise RequestError.new(e.message)
    end

    private

    attr_reader :url

    def extract_boundary!(content_type)
      match_data = BOUNDARY_REGEXP.match(content_type)
      raise ResponseError.new('failed to find multipart boundary in Content-Type header') if match_data.nil?

      match_data.captures.first
    end

    def validate_status!(response:, statuses:)
      raise ResponseError.new("failed with status: #{response.status}, body: #{response.body}") unless statuses.include?(response.status)
    end

    def protobuf_decode!(message, protobuf_decoder)
      protobuf_decoder.decode(message)
    rescue => e
      raise DecodeError.new(e.message)
    end

    def client
      @client ||= build_client
    end

    def build_client
      client                        = HTTPClient.new(base_url: url)
      client.connect_timeout        = 10
      client.send_timeout           = 10
      client.receive_timeout        = 10
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client
    end
  end
end
