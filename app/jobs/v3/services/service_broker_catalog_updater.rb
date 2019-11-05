module VCAP::CloudController
  module V3
    class ServiceBrokerCatalogUpdater
      attr_reader :warnings

      def initialize(broker)
        @broker = broker
        @formatter = VCAP::Services::ServiceBrokers::ValidationErrorsFormatter.new
        @service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithBrokerActor.new
        @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker, service_event_repository)
        @service_manager = VCAP::Services::ServiceBrokers::ServiceManager.new(service_event_repository)
      end

      def refresh
        catalog = VCAP::Services::ServiceBrokers::V2::Catalog.new(broker, broker_client.catalog)

        raise fail_with_invalid_catalog(catalog.validation_errors) unless catalog.valid?
        raise fail_with_incompatible_catalog(catalog.incompatibility_errors) unless catalog.compatible?

        unless client_manager.synchronize_clients_with_catalog(catalog)
          raise fail_with_invalid_catalog(client_manager.errors)
        end

        service_manager.sync_services_and_plans(catalog)

        collect_warnings
      end

      private

      attr_reader :broker,
          :formatter, :client_manager, :service_event_repository,
          :service_manager

      def broker_client
        @broker_client ||= VCAP::Services::ServiceClientProvider.provide(broker: broker)
      end

      def fail_with_invalid_catalog(errors)
        full_message = formatter.format(errors)
        raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', full_message)
      end

      def fail_with_incompatible_catalog(errors)
        full_message = formatter.format(errors)
        raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogIncompatible', full_message)
      end

      def collect_warnings
        (service_manager.warnings + client_manager.warnings).map { |w| { detail: w } }
      end
    end
  end
end
