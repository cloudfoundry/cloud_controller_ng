require 'jobs/v3/delete_service_instance_job'
require 'actions/services/locks/deleter_lock'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
      class AssociationNotEmptyError < StandardError
      end

      class InstanceSharedError < StandardError
      end

      class DeleteFailed < StandardError
      end

      DeleteStatus = Struct.new(:finished, :operation).freeze
      DeleteStarted = ->(operation) { DeleteStatus.new(false, operation) }
      DeleteComplete = DeleteStatus.new(true, nil).freeze

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      def initialize(service_instance, event_repo)
        @service_instance = service_instance
        @service_event_repository = event_repo
      end

      def delete
        operation_in_progress! if service_instance.operation_in_progress? && service_instance.last_operation.type != 'create'

        result = send_deprovison_to_broker
        if result[:finished]
          destroy
          record_delete_event
        else
          update_last_operation_with_operation_id(result[:operation])
          record_start_delete_event
        end

        result
      rescue => e
        update_last_operation_with_failure(e.message) unless service_instance.operation_in_progress?
        raise e
      end

      def delete_checks
        association_not_empty! if service_instance.has_bindings? || service_instance.has_keys? || service_instance.has_routes?
        cannot_delete_shared_instances! if service_instance.shared?
      end

      def poll
        result = client.fetch_service_instance_last_operation(service_instance)
        case result[:last_operation][:state]
        when 'in progress'
          update_last_operation_with_description(result[:last_operation][:description])
          ContinuePolling.call(result[:retry_after])
        when 'succeeded'
          destroy
          PollingFinished
        else
          delete_failed!(result[:last_operation][:description])
        end
      rescue DeleteFailed => e
        update_last_operation_with_failure(e.message)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'delete', e.message)
      rescue => e
        update_last_operation_with_failure(e.message)
        ContinuePolling.call(nil)
      end

      def update_last_operation_with_failure(message)
        service_instance.save_with_new_operation(
          {},
          {
            type: 'delete',
            state: 'failed',
            description: message,
          }
        )
      end

      private

      attr_reader :service_event_repository, :service_instance

      def client
        VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
      end

      def send_deprovison_to_broker
        result = client.deprovision(service_instance, accepts_incomplete: true)
        return DeleteComplete if result[:last_operation][:state] == 'succeeded'

        DeleteStarted.call(result[:last_operation][:broker_provided_operation])
      end

      def record_delete_event
        case service_instance
        when VCAP::CloudController::ManagedServiceInstance
          service_event_repository.record_service_instance_event(:delete, service_instance)
        when VCAP::CloudController::UserProvidedServiceInstance
          service_event_repository.record_user_provided_service_instance_event(:delete, service_instance)
        end
      end

      def record_start_delete_event
        service_event_repository.record_service_instance_event(:start_delete, service_instance)
      end

      def destroy
        ServiceInstance.db.transaction do
          service_instance.lock!
          service_instance.last_operation&.destroy
          service_instance.destroy
        end
      end

      def update_last_operation_with_operation_id(operation_id)
        service_instance.save_with_new_operation(
          {},
          {
            type: 'delete',
            state: 'in progress',
            broker_provided_operation: operation_id
          }
        )
      end

      def update_last_operation_with_description(description)
        lo = service_instance.last_operation.to_hash
        lo[:broker_provided_operation] = service_instance.last_operation.broker_provided_operation
        lo[:description] = description
        service_instance.save_with_new_operation({}, lo)
      end

      def association_not_empty!
        raise AssociationNotEmptyError
      end

      def cannot_delete_shared_instances!
        raise InstanceSharedError
      end

      def operation_in_progress!
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
      end

      def delete_failed!(message)
        raise DeleteFailed.new(message)
      end
    end
  end
end
