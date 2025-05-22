require 'diego/bbs/bbs'
require 'diego/errors'
require 'diego/routes'
require 'http/httpclient'

module Diego
  class Client
    def initialize(url:, ca_cert_file:, client_cert_file:, client_key_file:,
                   connect_timeout:, send_timeout:, receive_timeout:)
      ENV['PB_IGNORE_DEPRECATIONS'] ||= 'true'
      @logger = Steno.logger('cc.diego.client')
      @client = build_client(
        url,
        ca_cert_file,
        client_cert_file,
        client_key_file,
        connect_timeout,
        send_timeout,
        receive_timeout
      )
    end

    def upsert_domain(domain:, ttl:)
      request = protobuf_encode!({ domain: domain, ttl: ttl.to_i }, Bbs::Models::UpsertDomainRequest)

      response = with_request_error_handling do
        client.post(Routes::UPSERT_DOMAIN, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::UpsertDomainResponse)
    end

    def desire_task(task_definition:, domain:, task_guid:)
      request = protobuf_encode!({ task_definition:, domain:, task_guid: }, Bbs::Models::DesireTaskRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRE_TASK, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def task_by_guid(task_guid)
      request = protobuf_encode!({ task_guid: }, Bbs::Models::TaskByGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::TASK_BY_GUID, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskResponse)
    end

    def tasks(domain: '', cell_id: '')
      request = protobuf_encode!({ domain:, cell_id: }, Bbs::Models::TasksRequest)

      response = with_request_error_handling do
        client.post(Routes::LIST_TASKS, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::TasksResponse)
    end

    def cancel_task(task_guid)
      request = protobuf_encode!({ task_guid: }, Bbs::Models::TaskGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::CANCEL_TASK, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def desire_lrp(lrp)
      request = protobuf_encode!({ desired_lrp: lrp }, Bbs::Models::DesireLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRE_LRP, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def desired_lrp_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: }, Bbs::Models::DesiredLRPByProcessGuidRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRED_LRP_BY_PROCESS_GUID, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPResponse)
    end

    def desired_lrps_by_process_guids(process_guids)
      request = protobuf_encode!({ process_guids: }, Bbs::Models::DesiredLRPsRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRED_LRPS, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPsResponse)
    end

    def update_desired_lrp(process_guid, lrp_update)
      request = protobuf_encode!({ process_guid: process_guid, update: lrp_update }, Bbs::Models::UpdateDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::UPDATE_DESIRED_LRP, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def remove_desired_lrp(process_guid)
      request = protobuf_encode!({ process_guid: }, Bbs::Models::RemoveDesiredLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::REMOVE_DESIRED_LRP, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def retire_actual_lrp(actual_lrp_key)
      request = protobuf_encode!({ actual_lrp_key: }, Bbs::Models::RetireActualLRPRequest)

      response = with_request_error_handling do
        client.post(Routes::RETIRE_ACTUAL_LRP, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::ActualLRPLifecycleResponse)
    end

    def desired_lrp_scheduling_infos(domain)
      request = protobuf_encode!({ domain: }, Bbs::Models::DesiredLRPsRequest)

      response = with_request_error_handling do
        client.post(Routes::DESIRED_LRP_SCHEDULING_INFOS, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPSchedulingInfosResponse)
    end

    def actual_lrps_by_process_guid(process_guid)
      request = protobuf_encode!({ process_guid: }, Bbs::Models::ActualLRPsRequest)

      response = with_request_error_handling do
        client.post(Routes::ACTUAL_LRPS, request, headers)
      end

      validate_status_200!(response)
      protobuf_decode!(response.body, Bbs::Models::ActualLRPsResponse)
    end

    def with_request_error_handling
      delay = 0.25
      max_delay = 5
      retry_until = Time.now.utc + 60 # retry for 1 minute from now
      factor = 2

      begin
        yield
      rescue StandardError => e
        if Time.now.utc > retry_until
          @logger.error('Unable to establish a connection to diego backend, no more retries, raising an exception.')
          raise RequestError.new(e.message)
        else
          sleep_time = [delay, max_delay].min
          @logger.info("Attempting to connect to the diego backend. Total #{(retry_until - Time.now.utc).round(2)} seconds remaining. Next retry after #{sleep_time} seconds.")
          sleep(sleep_time)
          delay *= factor
          retry
        end
      end
    end

    private

    attr_reader :client

    def protobuf_encode!(hash, protobuf_message_class)
      # See below link to understand proto3 message encoding
      # https://developers.google.com/protocol-buffers/docs/reference/ruby-generated#message
      protobuf_message_class.encode(protobuf_message_class.new(hash))
    rescue StandardError => e
      raise EncodeError.new(e.message)
    end

    def validate_status_200!(response)
      raise ResponseError.new("failed with status: #{response.status}, body: #{response.body}") unless response.status == 200
    end

    def protobuf_decode!(message, protobuf_decoder)
      protobuf_decoder.decode(message)
    rescue StandardError => e
      raise DecodeError.new(e.message)
    end

    def build_client(url, ca_cert_file, client_cert_file, client_key_file,
                     connect_timeout, send_timeout, receive_timeout)
      client                        = HTTPClient.new(base_url: url)
      client.socket_connect_timeout = connect_timeout / 2
      client.connect_timeout        = connect_timeout
      client.send_timeout           = send_timeout
      client.receive_timeout        = receive_timeout
      client.ssl_config.set_client_cert_file(client_cert_file, client_key_file)
      client.ssl_config.set_trust_ca(ca_cert_file)
      client
    end

    def headers
      { 'Content-Type' => 'application/x-protobuf', 'X-Vcap-Request-Id' => ::VCAP::Request.current_id.to_s.split(':')[0].to_s }
    end
  end
end
