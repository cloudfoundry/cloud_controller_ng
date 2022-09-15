require 'services/service_brokers/service_client_provider'
require 'actions/mixins/service_instance_create'
require 'actions/metadata_update'

module VCAP::CloudController
  module V3
    class ServiceInstanceCreateManaged
      include ServiceInstanceCreateMixin

      class InvalidManagedServiceInstance < StandardError; end
      class LastOperationFailedState < StandardError; end

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      def initialize(user_audit_info, audit_hash)
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
      end

      def precursor(message:, service_plan:)
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
          state: ManagedServiceInstance::INITIAL_STRING
        }

        instance = ManagedServiceInstance.first(name: message.name, space: Space.where(guid: message.space_guid))

        ManagedServiceInstance.new.tap do |i|
          ManagedServiceInstance.db.transaction do
            instance.destroy if instance&.create_failed?
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

        if details[:last_operation][:state] == 'in progress'
          save_incomplete_instance(instance, details)
        else
          complete_instance_and_save(instance, details)
        end
      rescue => e
        save_failed_state(instance, e)

        raise e
      end

      def poll(instance)
        logger = Steno.logger('cc.action.service_instance_create_managed')
        client = VCAP::Services::ServiceClientProvider.provide(instance: instance)
        begin
          last_operation_result = client.fetch_service_instance_last_operation(instance, user_guid: @user_audit_info.user_guid)
        rescue HttpRequestError, HttpResponseError, Sequel::Error => e
          logger.error("Error fetching last operation from broker for service instance #{instance.guid}", error: e)
          return ContinuePolling.call(nil)
        end

        case last_operation_result[:last_operation][:state]
        when 'succeeded'
          fetch_result = fetch_service_instance(client, instance)
          complete_instance_and_save(instance, parse_response(fetch_result, last_operation_result))
          return PollingFinished
        when 'in progress'
          save_last_operation(instance, last_operation_result[:last_operation])
          ContinuePolling.call(last_operation_result[:retry_after])
        when 'failed'
          save_last_operation(instance, last_operation_result[:last_operation])
          raise LastOperationFailedState.new(last_operation_result[:last_operation][:description])
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

      def instances_retrievable?(instance)
        instance.service.instances_retrievable
      end

      def complete_instance_and_save(instance, broker_response)
        save_instance(broker_response, instance)
        event_repository.record_service_instance_event(:create, instance, @audit_hash)
      end

      def save_incomplete_instance(instance, broker_response)
        save_instance(broker_response, instance)
        event_repository.record_service_instance_event(:start_create, instance, @audit_hash)
      end

      def save_failed_state(instance, e)
        save_instance(
          {
            last_operation: {
              type: 'create',
              state: 'failed',
              description: e.message,
            }
          }, instance
        )
      end

      def save_last_operation(instance, last_operation)
        save_instance(
          {
            last_operation: {
              type: 'create',
              state: last_operation[:state],
              description: last_operation[:description],
              broker_provided_operation: instance.last_operation.broker_provided_operation
            }
          }, instance
        )
      end

      def save_instance(broker_response, instance)
        instance.save_with_new_operation(
          broker_response[:instance] || {},
          broker_response[:last_operation] || {}
        )
      end

      def fetch_service_instance(client, instance)
        logger = Steno.logger('cc.action.service_instance_create_managed')

        result = {}
        begin
          if instance.service.instances_retrievable
            fetch_result = client.fetch_service_instance(instance, user_guid: @user_audit_info.user_guid)
            result[:dashboard_url] = fetch_result[:dashboard_url] if fetch_result.key?(:dashboard_url)
          end
        rescue => e
          logger.info('fetch-service-instance-failed', error: e.class.name, error_message: e.message)
        end

        result
      end

      def parse_response(fetch_instance, last_operation)
        {
          instance: fetch_instance,
          last_operation: {
            state: last_operation[:last_operation][:state],
            type: 'create',
            description: last_operation[:last_operation][:description]
          }
        }
      end

      def broker_unavailable!
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          'The service instance cannot be created because there is an operation in progress for the service broker.')
      end

      class ValidationErrorHandler
        def error!(message)
          raise InvalidManagedServiceInstance.new(message)
        end
      end
    end
  end
end
