require_relative 'asynchronous_operations'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceBindingStateFetch < VCAP::CloudController::Jobs::CCJob
        include AsynchronousOperations

        attr_accessor :service_binding_guid, :end_timestamp, :user_audit_info, :request_attrs, :poll_interval, :retry_number

        def initialize(service_binding_guid, user_info, request_attrs)
          @service_binding_guid = service_binding_guid
          @end_timestamp = new_end_timestamp
          @user_audit_info = user_info
          @request_attrs = request_attrs
          @retry_number = 0
          update_polling_interval
        end

        def perform
          logger = Steno.logger('cc-background')

          service_binding = ServiceBinding.first(guid: service_binding_guid)
          return if service_binding.nil? # assume the binding has been purged

          intended_operation = service_binding.last_operation

          client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
          last_operation_result = client.fetch_service_binding_last_operation(service_binding)
          raise "Invalid response from client: #{last_operation_result}" unless valid_client_response?(last_operation_result)

          if service_binding.last_operation.type == 'create'
            create_result = process_create_operation(logger, service_binding, last_operation_result, intended_operation)
            return if create_result[:finished]
          elsif service_binding.last_operation.type == 'delete'
            delete_result = process_delete_operation(service_binding, last_operation_result)
            return if delete_result[:finished]
          end

          retry_job(retry_after_header: last_operation_result[:retry_after]) unless service_binding.terminal_state?
        rescue HttpResponseError,
               HttpRequestError,
               Sequel::Error,
               VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout,
               VCAP::Services::ServiceBrokers::V2::Errors::HttpClientTimeout => e
          logger.error("There was an error while fetching the service binding operation state: #{e}")
          retry_job
        end

        def display_name
          'service_binding.state_fetch'
        end

        def max_attempts
          1
        end

        private

        def process_create_operation(logger, service_binding, last_operation_result, intended_operation)
          if state_succeeded?(last_operation_result)
            client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)

            begin
              binding_response = client.fetch_service_binding(service_binding)
            rescue HttpResponseError, VCAP::Services::ServiceBrokers::V2::Errors::HttpClientTimeout => e
              set_binding_failed_state(service_binding, logger)
              logger.error("There was an error while fetching the service binding details: #{e}")
              return { finished: true }
            end

            ServiceBinding.db.transaction do
              service_binding.lock!
              return { finished: false } if intended_operation != service_binding.last_operation

              service_binding.update({
                'credentials'      => binding_response[:credentials],
                'syslog_drain_url' => binding_response[:syslog_drain_url],
                'volume_mounts' => binding_response[:volume_mounts],
              })
              record_event(service_binding, request_attrs)
              service_binding.last_operation.update(last_operation_result[:last_operation])
            end
            return { finished: true }
          end

          ServiceBinding.db.transaction do
            service_binding.lock!
            service_binding.last_operation.update(last_operation_result[:last_operation])
          end

          { finished: false }
        end

        def process_delete_operation(service_binding, last_operation_result)
          if state_succeeded?(last_operation_result)
            service_binding.destroy
            record_event(service_binding, request_attrs)
            return { finished: true }
          end

          ServiceBinding.db.transaction do
            service_binding.lock!
            service_binding.last_operation.update(last_operation_result[:last_operation])
          end
          { finished: false }
        end

        def end_timestamp_reached
          binding_last_operation = ServiceBinding.first(guid: service_binding_guid).last_operation
          binding_last_operation.update(
            state: 'failed',
            description: "Service Broker failed to #{binding_last_operation.type} binding within the required time."
          )
        end

        def record_event(binding, request_attrs)
          repository = Repositories::ServiceBindingEventRepository
          operation_type = binding.last_operation.type

          if operation_type == 'create'
            repository.record_create(binding, user_audit_info, request_attrs)
          elsif operation_type == 'delete'
            repository.record_delete(binding, user_audit_info)
          end
        end

        def set_binding_failed_state(service_binding, logger)
          service_binding.last_operation.update(
            state: 'failed',
            description: 'A valid binding could not be fetched from the service broker.',
          )
        end

        def state_succeeded?(last_operation_result)
          last_operation_result[:last_operation][:state] == 'succeeded'
        end

        def valid_client_response?(last_operation_result)
          last_operation_result.key?(:last_operation)
        end

        def service_plan
          ServiceBinding.first(guid: service_binding_guid).try(:service_plan)
        rescue Sequel::Error => e
          Steno.logger('cc-background').error("There was an error while fetching the service binding: #{e}")
          nil
        end
      end
    end
  end
end
