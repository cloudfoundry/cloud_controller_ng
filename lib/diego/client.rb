require 'diego/bbs/bbs'
require 'diego/errors'
require 'diego/routes'

module Diego
  class Client
    PROTOBUF_HEADER = { 'Content-Type'.freeze => 'application/x-protobuf'.freeze }.freeze

    def initialize(url:, ca_cert_file:, client_cert_file:, client_key_file:)
      @client = build_client(url, ca_cert_file, client_cert_file, client_key_file)
    end

    def ping
      response = with_request_error_handling do
        client.post(Routes::PING)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::PingResponse)
    end

    def upsert_domain(domain:, ttl:)
      request = protobuf_encode!({ domain: domain, ttl: ttl }, Bbs::Models::UpsertDomainRequest)

      response = with_request_error_handling do
        client.post(Routes::UPSERT_DOMAIN, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::UpsertDomainResponse)
    end

    def desire_task(task_definition:, domain:, task_guid:)
      request = protobuf_encode!({ task_definition: task_definition, domain: domain, task_guid: task_guid }, Bbs::Models::DesireTaskRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRE_TASK, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def task_by_guid(task_guid)
      request = protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskByGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::TASK_BY_GUID, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskResponse)
    end

    def tasks(domain: nil, cell_id: nil)
      request = protobuf_encode!({ domain: domain, cell_id: cell_id }, Bbs::Models::TasksRequest)

      response = with_request_error_handling do
        client.post(Routes::LIST_TASKS, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TasksResponse)
    end

    def cancel_task(task_guid)
      request = protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::CANCEL_TASK, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def desire_lrp(lrp)
      request = protobuf_encode!({ desired_lrp: lrp }, Bbs::Models::DesireLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRE_LRP, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def desired_lrp_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::DesiredLRPByProcessGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRED_LRP_BY_PROCESS_GUID, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPResponse)
    end

    def update_desired_lrp(process_guid, lrp_update)
      request = protobuf_encode!({ process_guid: process_guid, update: lrp_update }, Bbs::Models::UpdateDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::UPDATE_DESIRED_LRP, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def remove_desired_lrp(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::RemoveDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::REMOVE_DESIRED_LRP, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def retire_actual_lrp(actual_lrp_key)
      request = protobuf_encode!({ actual_lrp_key: actual_lrp_key }, Bbs::Models::RetireActualLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::RETIRE_ACTUAL_LRP, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::ActualLRPLifecycleResponse)
    end

    def desired_lrp_scheduling_infos(domain)
      request = protobuf_encode!({ domain: domain }, Bbs::Models::DesiredLRPsRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRED_LRP_SCHEDULING_INFOS, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPSchedulingInfosResponse)
    end

    def actual_lrp_groups_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: process_guid }, Bbs::Models::ActualLRPGroupsByProcessGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::ACTUAL_LRP_GROUPS, request, PROTOBUF_HEADER)
      end

      validate_status!(response: response, statuses: [200])
      protobuf_decode!(response.body, Bbs::Models::ActualLRPGroupsResponse)
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue => e
      retry unless (tries -= 1).zero?
      raise RequestError.new(e.message)
    end

    private

    attr_reader :client

    def protobuf_encode!(object, encoder)
      encoder.encode(object)
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

    def build_client(url, ca_cert_file, client_cert_file, client_key_file)
      client                 = HTTPClient.new(base_url: url)
      client.connect_timeout = 10
      client.send_timeout    = 10
      client.receive_timeout = 10
      client.ssl_config.set_client_cert_file(client_cert_file, client_key_file)
      client.ssl_config.set_trust_ca(ca_cert_file)
      client
    end
  end
end
