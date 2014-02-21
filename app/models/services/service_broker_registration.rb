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

      catalog.create_service_dashboard_clients

      broker.db.transaction(savepoint: true) do
        broker.save
        catalog.sync_services_and_plans
      end

      return self
    end

    def build_catalog(catalog_hash)
      catalog = VCAP::CloudController::ServiceBroker::V2::Catalog.new(broker, catalog_hash)
      raise VCAP::Errors::ServiceBrokerCatalogInvalid.new(catalog.error_text) unless catalog.valid?
      catalog
    end

    def errors
      broker.errors
    end
  end
end
