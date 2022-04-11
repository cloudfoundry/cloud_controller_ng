require_relative 'asynchronous_operations'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        include AsynchronousOperations

        attr_accessor :name, :service_instance_guid, :request_attrs, :poll_interval, :end_timestamp, :user_audit_info, :retry_number

        def initialize(name, service_instance_guid, user_audit_info, request_attrs, end_timestamp=nil)
          @name                  = name
          @service_instance_guid = service_instance_guid
          @request_attrs         = request_attrs
          @end_timestamp         = end_timestamp || new_end_timestamp
          @user_audit_info       = user_audit_info
          @retry_number          = 0
          update_polling_interval
        end

        def perform
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)
          return if service_instance.nil?

          intended_operation = service_instance.last_operation

          client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)

          last_operation_result = client.fetch_service_instance_last_operation(service_instance)
          update_with_attributes(last_operation_result[:last_operation], service_instance, intended_operation)

          retry_job(retry_after_header: last_operation_result[:retry_after]) unless service_instance.terminal_state?
        rescue HttpRequestError, HttpResponseError, Sequel::Error => e
          logger = Steno.logger('cc-background')
          logger.error("There was an error while fetching the service instance operation state: #{e}")
          retry_job
        end

        def job_name_in_configuration
          :service_instance_state_fetch
        end

        def display_name
          'service_instance.state_fetch'
        end

        def max_attempts
          1
        end

        private

        def repository
          Repositories::ServiceEventRepository.new(user_audit_info)
        end

        def update_with_attributes(last_operation, service_instance, intended_operation)
          ServiceInstance.db.transaction do
            service_instance.lock!
            return unless intended_operation == service_instance.last_operation

            service_instance.save_and_update_operation(
              last_operation: last_operation.slice(:state, :description)
            )

            if service_instance.last_operation.state == 'succeeded'
              apply_proposed_changes(service_instance)
              record_event(service_instance, request_attrs)
            end
          end
        end

        def end_timestamp_reached
          ManagedServiceInstance.first(guid: service_instance_guid).save_and_update_operation(
            last_operation: {
              state: 'failed',
              description: 'Service Broker failed to provision within the required time.',
            }
          )
        end

        def record_event(service_instance, request_attrs)
          type = service_instance.last_operation.type
          repository.record_service_instance_event(type, service_instance, request_attrs)
        end

        def apply_proposed_changes(service_instance)
          if service_instance.last_operation.type == 'delete'
            service_instance.last_operation.destroy
            service_instance.destroy
          else
            service_instance.save_and_update_operation(service_instance.last_operation.proposed_changes)
          end
        end

        def service_plan
          ManagedServiceInstance.first(guid: service_instance_guid).try(:service_plan)
        rescue Sequel::Error => e
          Steno.logger('cc-background').error("There was an error while fetching the service instance: #{e}")
          nil
        end
      end
    end
  end
end
