require 'jobs/v3/delete_service_instance_job'
require 'actions/service_route_binding_delete'
require 'actions/service_credential_binding_delete'
require 'actions/service_instance_unshare'
require 'cloud_controller/errors/api_error'
require 'actions/mixins/bindings_delete'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
      include BindingsDeleteMixin

      class DeleteFailed < StandardError
      end

      class UnbindingOperatationInProgress < StandardError
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

      def blocking_operation_in_progress?
        service_instance.operation_in_progress? &&
          (service_instance.create_initial? || service_instance.update_in_progress? || service_instance.delete_in_progress?)
      end

      def delete
        operation_in_progress! if blocking_operation_in_progress?

        errors = remove_associations
        raise errors.first if errors.any?

        result = send_deprovison_to_broker
        if result[:finished]
          perform_delete_actions
        else
          update_last_operation_with_operation_id(result[:operation])
          record_start_delete_event
        end

        return result
      rescue => e
        update_last_operation_with_failure(e.message) unless service_instance.operation_in_progress?
        raise e
      end

      def poll
        result = client.fetch_service_instance_last_operation(
          service_instance,
          user_guid: service_event_repository.user_audit_info.user_guid
        )
        case result[:last_operation][:state]
        when 'in progress'
          update_last_operation_with_description(result[:last_operation][:description])
          ContinuePolling.call(result[:retry_after])
        when 'succeeded'
          perform_delete_actions
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

      def perform_delete_actions
        destroy
        record_delete_event
      end

      attr_reader :service_event_repository, :service_instance

      def client
        VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
      end

      def send_deprovison_to_broker
        result = client.deprovision(
          service_instance,
          accepts_incomplete: true,
          user_guid: service_event_repository.user_audit_info.user_guid
        )
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

      def remove_associations
        errors = delete_bindings(RouteBinding.where(service_instance: service_instance), user_audit_info: service_event_repository.user_audit_info)
        errors += delete_bindings(service_instance.service_bindings, user_audit_info: service_event_repository.user_audit_info)
        errors += delete_bindings(service_instance.service_keys, user_audit_info: service_event_repository.user_audit_info)
        errors + unshare_all_spaces
      end

      def unshare_all_spaces
        # The array from `service_instance.shared_spaces` gets updated as spaces are unshared, so we make list of guids
        space_guids = service_instance.shared_spaces.map(&:guid)

        unshare_action = ServiceInstanceUnshare.new
        space_guids.each_with_object([]) do |space_guid, errors|
          unshare_action.unshare(service_instance, Space.first(guid: space_guid), service_event_repository.user_audit_info)
        rescue => e
          errors << e
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

      def operation_in_progress!
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
      end

      def unbinding_operation_in_progress!(binding)
        raise UnbindingOperatationInProgress.new(
          if binding.is_a?(VCAP::CloudController::ServiceBinding)
            "An operation for the service binding between app #{binding.app.name} and service instance #{service_instance.name} is in progress."
          else
            "An operation for a service binding of service instance #{service_instance.name} is in progress."
          end
        )
      end

      def delete_failed!(message)
        raise DeleteFailed.new(message)
      end
    end
  end
end
