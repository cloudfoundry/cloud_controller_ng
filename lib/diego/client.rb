require 'diego/bbs/bbs'
require 'diego/errors'
require 'diego/routes'
require 'uri'
require 'locket/client'

module Diego
  class Client
    PROTOBUF_HEADER = { 'Content-Type'.freeze => 'application/x-protobuf'.freeze }.freeze

    def initialize(url:, ca_cert_file:, client_cert_file:, client_key_file:,
      connect_timeout:, send_timeout:, receive_timeout:, locket_config:)
      ENV['PB_IGNORE_DEPRECATIONS'] ||= 'true'
      @client = build_client(
        ca_cert_file,
        client_cert_file,
        client_key_file,
        connect_timeout,
        send_timeout,
        receive_timeout)
      @locket_config = locket_config
      @base_url = url
    end

    def ping
      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::PING))
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::PingResponse)
    end

    def upsert_domain(domain:, ttl:)
      request = protobuf_encode!({ domain: domain, ttl: ttl.to_i }, Bbs::Models::UpsertDomainRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::UPSERT_DOMAIN), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::UpsertDomainResponse)
    end

    def desire_task(task_definition:, domain:, task_guid:)
      request = protobuf_encode!({ task_definition: task_definition, domain: domain, task_guid: task_guid }, Bbs::Models::DesireTaskRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::DESIRE_TASK), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def task_by_guid(task_guid)
      request = protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskByGuidRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::TASK_BY_GUID), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskResponse)
    end

    def tasks(domain: '', cell_id: '')
      request = protobuf_encode!({ domain: domain, cell_id: cell_id }, Bbs::Models::TasksRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::LIST_TASKS), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TasksResponse)
    end

    def cancel_task(task_guid)
      request = protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskGuidRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::CANCEL_TASK), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def desire_lrp(lrp)
      request = protobuf_encode!({ desired_lrp: lrp }, Bbs::Models::DesireLRPRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::DESIRE_LRP), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def desired_lrp_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::DesiredLRPByProcessGuidRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::DESIRED_LRP_BY_PROCESS_GUID), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPResponse)
    end

    def update_desired_lrp(process_guid, lrp_update)
      request = protobuf_encode!({ process_guid: process_guid, update: lrp_update }, Bbs::Models::UpdateDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::UPDATE_DESIRED_LRP), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def remove_desired_lrp(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::RemoveDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::REMOVE_DESIRED_LRP), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def retire_actual_lrp(actual_lrp_key)
      request = protobuf_encode!({ actual_lrp_key: actual_lrp_key }, Bbs::Models::RetireActualLRPRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::RETIRE_ACTUAL_LRP), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::ActualLRPLifecycleResponse)
    end

    def desired_lrp_scheduling_infos(domain)
      request = protobuf_encode!({ domain: domain }, Bbs::Models::DesiredLRPsRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::DESIRED_LRP_SCHEDULING_INFOS), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPSchedulingInfosResponse)
    end

    def actual_lrps_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::ActualLRPsRequest)

      response = with_request_error_handling do
        client.post(URI.join(bbs_url, Routes::ACTUAL_LRPS), request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::ActualLRPsResponse)
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue => e
      @cached_active_bbs_id = nil
      retry unless (tries -= 1).zero?
      raise RequestError.new(e.message)
    end

    def bbs_url
      uri = URI(base_url)
      uri.host = "#{active_bbs_id}.#{uri.host}"
      uri.to_s
    end

    def active_bbs_id
      tries ||= 3
      @cached_active_bbs_id ||= latest_active_bbs_id
    rescue GRPC::BadStatus => e
      retry unless (tries -= 1).zero?
      raise e
    end

    private

    attr_reader :client, :base_url, :locket_config
    attr_accessor :cached_active_bbs_id

    def protobuf_encode!(hash, protobuf_message_class)
      # See below link to understand proto3 message encoding
      # https://developers.google.com/protocol-buffers/docs/reference/ruby-generated#message
      protobuf_message_class.encode(protobuf_message_class.new(hash))
    rescue => e
      raise EncodeError.new(e.message)
    end

    def validate_status!(response:, statuses:)
      raise ResponseError.new("failed with status: #{response.status}, body: #{response.body}") unless statuses.include?(response.status)
    end

    def protobuf_decode!(message, protobuf_decoder)
      protobuf_decoder.decode(message)
    rescue => e
      raise DecodeError.new(e.message)
    end

    def build_client(ca_cert_file, client_cert_file, client_key_file,
      connect_timeout, send_timeout, receive_timeout)
      client                 = HTTPClient.new
      client.connect_timeout = connect_timeout
      client.send_timeout    = send_timeout
      client.receive_timeout = receive_timeout
      client.ssl_config.set_client_cert_file(client_cert_file, client_key_file)
      client.ssl_config.set_trust_ca(ca_cert_file)
      client
    end

    def latest_active_bbs_id
      locket_client.fetch(key: 'bbs').resource.owner
    end

    def locket_client
      Locket::Client.new(
        host: locket_config[:host],
        port: locket_config[:port],
        client_ca_path: locket_config[:ca_file],
        client_key_path: locket_config[:key_file],
        client_cert_path: locket_config[:cert_file],
        timeout: locket_config[:diego_client_timeout]
      )
    end
  end
end
