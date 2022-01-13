module VCAP::CloudController
  module V3
    class ServiceBrokerCatalogUpdater
      attr_reader :warnings

      def initialize(broker, user_audit_info:)
        @broker = broker
        @formatter = VCAP::Services::ServiceBrokers::ValidationErrorsFormatter.new
        @service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
        @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker, service_event_repository)
        @service_manager = VCAP::Services::ServiceBrokers::ServiceManager.new(service_event_repository)
      end

      def refresh
        catalog = VCAP::Services::ServiceBrokers::V2::Catalog.new(
          broker,
          broker_client.catalog(user_guid: service_event_repository.user_audit_info.user_guid)
        )

        raise fail_with_invalid_catalog(catalog.validation_errors) unless catalog.valid?
        raise fail_with_incompatible_catalog(catalog.incompatibility_errors) unless catalog.compatible?

        unless client_manager.synchronize_clients_with_catalog(catalog)
          raise fail_with_invalid_catalog(client_manager.errors)
        end

        service_manager.sync_services_and_plans(catalog)
        collect_warnings
      rescue VCAP::Services::ServiceBrokers::ServiceManager::ServiceBrokerSyncError => e
        raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerSyncFailed', e.message)
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed
        raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerRequestMalformed')
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerRequestRejected => e
        raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerRequestRejected', "#{e.response.code} #{e.response.message}")
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
