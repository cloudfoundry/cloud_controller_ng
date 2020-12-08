require 'jobs/v3/delete_service_instance_job'
require 'actions/service_route_binding_delete'
require 'actions/service_credential_binding_delete'
require 'actions/service_instance_unshare'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
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

        errors = remove_associations
        raise errors.first if errors.any?

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

      def remove_associations
        errors = []

        route_bindings_action = ServiceRouteBindingDelete.new(service_event_repository.user_audit_info)
        errors += iterate_collecting_errors(RouteBinding.where(service_instance: service_instance)) do |route_binding|
          route_bindings_action.delete(route_binding)
        end

        service_bindings_action = ServiceCredentialBindingDelete.new(:credential, service_event_repository.user_audit_info)
        errors += iterate_collecting_errors(service_instance.service_bindings) do |service_binding|
          service_bindings_action.delete(service_binding)
        end

        service_key_action = ServiceCredentialBindingDelete.new(:key, service_event_repository.user_audit_info)
        errors += iterate_collecting_errors(service_instance.service_keys) do |service_key|
          service_key_action.delete(service_key)
        end

        unshare_action = ServiceInstanceUnshare.new
        # The array from `service_instance.shared_spaces` gets updated as spaces are unshared, hence we make list of guids
        errors += iterate_collecting_errors(service_instance.shared_spaces.map(&:guid)) do |space_guid|
          unshare_action.unshare(service_instance, Space.first(guid: space_guid), service_event_repository.user_audit_info)
        end

        errors
      end

      def remove_bindings
        errors = []
        route_bindings_action = ServiceRouteBindingDelete.new(service_event_repository.user_audit_info)
        RouteBinding.where(service_instance: service_instance).each do |route_binding|
          route_bindings_action.delete(route_binding)
        rescue => e
          errors << e
        end

        service_bindings_action = ServiceCredentialBindingDelete.new(:credential, service_event_repository.user_audit_info)
        service_instance.service_bindings.each do |service_binding|
          service_bindings_action.delete(service_binding)
        rescue => e
          errors << e
        end

        return errors
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

      def delete_failed!(message)
        raise DeleteFailed.new(message)
      end

      def iterate_collecting_errors(list)
        errors = []
        list.each do |item|
          yield(item)
        rescue => e
          errors << e
        end

        errors
      end
    end
  end
end
