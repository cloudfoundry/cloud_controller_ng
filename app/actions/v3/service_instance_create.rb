require 'services/service_brokers/service_client_provider'
require 'actions/mixins/service_instance_create'
require 'actions/metadata_update'

module VCAP::CloudController
  module V3
    class LastOperationFailedState < StandardError
    end

    class ServiceInstanceCreate
      include ServiceInstanceCreateMixin

      class InvalidManagedServiceInstance < StandardError
      end

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      CREATE_IN_PROGRESS_OPERATION = { type: 'create', state: 'in progress' }.freeze

      def initialize(user_audit_info, audit_hash)
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
      end

      def precursor(message:)
        service_plan = ServicePlan.first(guid: message.service_plan_guid)
        plan_not_found! unless service_plan

        broker_unavailable! unless service_plan.service_broker.available?

        attr = {
          name: message.name,
          space_guid: message.space_guid,
          tags: message.tags,
          service_plan: service_plan,
          maintenance_info: service_plan.maintenance_info
        }

        last_operation = {
          type: 'create',
          state: ManagedServiceInstance::IN_PROGRESS_STRING
        }

        ManagedServiceInstance.new.tap do |i|
          ManagedServiceInstance.db.transaction do
            i.save_with_new_operation(attr, last_operation)
            MetadataUpdate.update(i, message)
          end
        end
      rescue Sequel::ValidationFailed => e
        validation_error!(
          e,
          name: message.name,
          validation_error_handler: ValidationErrorHandler.new
        )
      end

      def provision(instance, parameters: {}, accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: instance)
        details = client.provision(
          instance,
          arbitrary_parameters: parameters,
          accepts_incomplete: accepts_incomplete,
          maintenance_info: instance.service_plan.maintenance_info,
          user_guid: @user_audit_info.user_guid
        )

        if details[:last_operation][:state] == 'in progress' && details[:last_operation][:type] == 'create'
          save_incomplete_instance(instance, details)
        else
          complete_instance_and_save(instance, details[:instance], details[:last_operation])
        end
      rescue => e
        save_failed_state(instance, e)

        raise e
      end

      def poll(instance)
        client = VCAP::Services::ServiceClientProvider.provide(instance: instance)
        details = client.fetch_service_instance_last_operation(instance, user_guid: @user_audit_info.user_guid)

        case details[:last_operation][:state]
        when 'succeeded'
          # TODO: If instance retrievable update dashboard
          # params = client.fetch_service_instance(instance, user_guid: @user_audit_info.user_guid)
          last_operation = {
            state: details[:last_operation][:state],
            type: 'create',
            description: details[:last_operation][:description]
          }
          complete_instance_and_save(instance, {}, last_operation)
          return PollingFinished
        when 'in progress'
          save_last_operation(instance, details)
          ContinuePolling.call(details[:retry_after])
        when 'failed'
          save_last_operation(instance, details)
          raise LastOperationFailedState
        end
      rescue LastOperationFailedState => e
        raise e
      rescue => e
        save_failed_state(instance, e)
        raise e
      end

      private

      def event_repository
        Repositories::ServiceEventRepository.new(@user_audit_info)
      end

      def save_failed_state(instance, e)
        instance.save_with_new_operation(
          {},
          {
            type: 'create',
            state: 'failed',
            description: e.message,
          }
        )
      end

      def complete_instance_and_save(instance, broker_instance_response, last_operation)
        instance.db.transaction do
          instance.lock!
          instance.last_operation.lock! if instance.last_operation
          instance.save_with_new_operation(
            broker_instance_response || {},
            last_operation || {}
          )
        end

        event_repository.record_service_instance_event(:create, instance, @audit_hash)
      end

      def save_last_operation(instance, details)
        instance.save_with_new_operation(
          {},
          {
            type: 'create',
            state: details[:last_operation][:state],
            description: details[:last_operation][:description],
            broker_provided_operation: instance.last_operation.broker_provided_operation
          }
        )
      end

      def save_incomplete_instance(instance, broker_response)
        ManagedServiceInstance.db.transaction do
          instance.lock!
          instance.last_operation.lock! if instance.last_operation
          instance.save_with_new_operation(
            broker_response[:instance] || {},
            broker_response[:last_operation] || {}
          )
        end

        event_repository.record_service_instance_event(:start_create, instance, @audit_hash)
      end

      def broker_unavailable!
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          'The service instance cannot be created because there is an operation in progress for the service broker.')
      end

      def plan_not_found!
        raise InvalidManagedServiceInstance.new('Service plan not found.')
      end

      class ValidationErrorHandler
        def error!(message)
          raise InvalidManagedServiceInstance.new(message)
        end
      end
    end
  end
end
