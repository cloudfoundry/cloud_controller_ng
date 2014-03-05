require 'models/services/service_brokers/v2/service_dashboard_client_manager'
require 'models/services/service_brokers/v2/validation_errors_formatter'

module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def save
      return unless broker.valid?

      catalog_hash = broker.client.catalog
      catalog      = build_catalog(catalog_hash)

      manager = ServiceBrokers::V2::ServiceDashboardClientManager.new(catalog)
      unless manager.create_service_dashboard_clients
        raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", formatter.format(manager.errors))
      end

      broker.db.transaction(savepoint: true) do
        broker.save
        catalog.sync_services_and_plans
      end

      return self
    end

    def formatter
      @formatter ||= ServiceBrokers::V2::ValidationErrorsFormatter.new
    end

    def build_catalog(catalog_hash)
      catalog = ServiceBrokers::V2::Catalog.new(broker, catalog_hash)
      unless catalog.valid?
        humanized_message = formatter.format(catalog.errors)
        raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", humanized_message)
      end
      catalog
    end

    def errors
      broker.errors
    end
  end
end
