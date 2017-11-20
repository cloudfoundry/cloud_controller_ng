# Copyright (c) 2009-2011 VMware, Inc.
require 'net/http'
require 'uri'

require 'vcap/services/api/const'
require 'vcap/services/api/messages'
require 'vcap/services/api/async_requests'

module VCAP
  module Services
    module Api
    end
  end
end

module VCAP::Services::Api
  class ServiceGatewayClient
    # Public: Indicate gateway client encounter an unexpected error,
    # such as can't connect to gateway or can't decode response.
    #
    class UnexpectedResponse < StandardError; end

    # Public: Indicate an error response from gateway
    #
    class ErrorResponse < StandardError
      attr_reader :status, :error

      # status - the http status
      # error  - a ServiceErrorResponse object
      #
      def initialize(status, error)
        @status = status
        @error = error
      end

      def to_s
        "#{self.class.name}: #{error.description}"
      end

      def to_h
        {
          'error' => error.extract(stringify_keys: true).merge(
            'backtrace' => backtrace,
            'types' => self.class.ancestors.map(&:name) - Exception.ancestors.map(&:name)
          )
        }
      end
    end

    class NotFoundResponse < ErrorResponse
      def initialize(error)
        super(404, error)
      end
    end

    class GatewayInternalResponse < ErrorResponse
      def initialize(error)
        super(503, error)
      end
    end

    attr_reader :http_client

    def initialize(url, token, timeout, request_id)
      @http_client = HttpClient.new(url, token, timeout, request_id)
    end

    def provision(args)
      msg = GatewayProvisionRequest.new(args)
      resp = http_client.perform_request(:post, '/gateway/v1/configurations', msg)
      GatewayHandleResponse.decode(resp)
    end

    def unprovision(args)
      http_client.perform_request(:delete, "/gateway/v1/configurations/#{args[:service_id]}")
      EMPTY_REQUEST
    end

    def bind(args)
      msg = GatewayBindRequest.new(args)
      resp = http_client.perform_request(:post, "/gateway/v1/configurations/#{msg.service_id}/handles", msg)
      GatewayHandleResponse.decode(resp)
    end

    def unbind(args)
      msg = GatewayUnbindRequest.new(args)
      http_client.perform_request(:delete, "/gateway/v1/configurations/#{msg.service_id}/handles/#{msg.handle_id}", msg)
      EMPTY_REQUEST
    end

    #------------------
    # Snapshotting has never been enabled in production - we can probably remove these
    #------------------

    def job_info(args)
      resp = http_client.perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/jobs/#{args[:job_id]}")
      Job.decode(resp)
    end

    def create_snapshot(args)
      resp = http_client.perform_request(:post, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
      Job.decode(resp)
    end

    def enum_snapshots(args)
      resp = http_client.perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
      SnapshotList.decode(resp)
    end

    def snapshot_details(args)
      resp = http_client.perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Snapshot.decode(resp)
    end

    def update_snapshot_name(args)
      http_client.perform_request(:post, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}/name", args[:msg])
      EMPTY_REQUEST
    end

    def rollback_snapshot(args)
      resp = http_client.perform_request(:put, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def delete_snapshot(args)
      resp = http_client.perform_request(:delete, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def create_serialized_url(args)
      resp = http_client.perform_request(:post, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def serialized_url(args)
      resp = http_client.perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url/snapshots/#{args[:snapshot_id]}")
      SerializedURL.decode(resp)
    end

    def import_from_url(args)
      resp = http_client.perform_request(:put, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url", args[:msg])
      Job.decode(resp)
    end

    class HttpClient
      METHODS_MAP = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete,
      }.freeze

      attr_reader :uri, :timeout, :token, :headers

      def initialize(uri, token, timeout, request_id)
        @uri = URI.parse(uri)
        @timeout = timeout
        @token = token
        @headers = {
          'Content-Type' => 'application/json',
          GATEWAY_TOKEN_HEADER => token,
          'X-VCAP-Request-ID' => request_id.to_s
        }
      end

      def perform_request(http_method, path, msg=EMPTY_REQUEST)
        klass = METHODS_MAP[http_method]
        request = klass.new(path, headers)
        request.body = msg.encode

        opts = {}
        if uri.scheme == 'https'
          opts[:use_ssl] = true
        end

        response = Net::HTTP.start(uri.host, uri.port, opts) do |http|
          http.request(request)
        end

        code = response.code.to_i
        body = response.body

        return body if code == 200

        begin
          err = ServiceErrorResponse.decode(body)
        rescue JsonMessage::Error
          raise UnexpectedResponse.new("Can't decode gateway response. status code: #{code}, response body: #{body}")
        end

        case code
        when 404 then raise NotFoundResponse.new(err)
        when 503 then raise GatewayInternalResponse.new(err)
        else raise ErrorResponse.new(code, err)
        end
      end
    end
  end
end
