module VCAP::CloudController
  module V3
    class SynchronizeBrokerCatalogJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :warnings

      def initialize(broker_guid)
        @broker_guid = broker_guid
      end

      def perform
        @warnings = Perform.new(@broker_guid).perform
      end

      def job_name_in_configuration
        :synchronize_service_broker_catalog
      end

      def max_attempts
        1
      end

      def resource_type
        'service_brokers'
      end

      def resource_guid
        broker_guid
      end

      def display_name
        'service_broker.catalog.synchronize'
      end

      private

      attr_reader :broker_guid

      class Perform
        def initialize(broker_guid)
          @broker_guid = broker_guid
          @broker = ServiceBroker.find(guid: broker_guid)
          @formatter = VCAP::Services::ServiceBrokers::ValidationErrorsFormatter.new
          @service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithBrokerActor.new
          @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker, service_event_repository)
          @service_manager = VCAP::Services::ServiceBrokers::ServiceManager.new(service_event_repository)
          @warnings = []
        end

        def perform
          ensure_state_present

          catalog = VCAP::Services::ServiceBrokers::V2::Catalog.new(broker, broker_client.catalog)

          raise fail_with_invalid_catalog(catalog.validation_errors) unless catalog.valid?
          raise fail_with_incompatible_catalog(catalog.incompatibility_errors) unless catalog.compatible?

          unless client_manager.synchronize_clients_with_catalog(catalog)
            raise fail_with_invalid_catalog(client_manager.errors)
          end

          service_manager.sync_services_and_plans(catalog)

          service_manager.warnings.each do |warning|
            warnings << { detail: warning.message }
          end

          client_manager.warnings.each do |warning|
            warnings << { detail: warning }
          end

          available_state
          warnings
        rescue
          failed_state
          raise
        end

        private

        attr_reader :broker_guid, :broker,
          :formatter, :client_manager, :service_event_repository,
          :service_manager, :warnings

        def broker_client
          @broker_client ||= VCAP::Services::ServiceClientProvider.provide(broker: broker)
        end

        def ensure_state_present
          if broker.service_broker_state.nil?
            broker.service_broker_state = ServiceBrokerState.new(
              state: ServiceBrokerStateEnum::SYNCHRONIZING
            )
          end
        end

        def failed_state
          broker.service_broker_state.update(
            state: ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED
        )
        end

        def available_state
          broker.service_broker_state.update(
            state: ServiceBrokerStateEnum::AVAILABLE
        )
        end

        def fail_with_invalid_catalog(errors)
          full_message = formatter.format(errors)
          raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', full_message)
        end

        def fail_with_incompatible_catalog(errors)
          full_message = formatter.format(errors)
          raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogIncompatible', full_message)
        end
      end
    end
  end
end
