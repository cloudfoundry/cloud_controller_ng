module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def save
      return unless broker.valid?

      broker.db.transaction(savepoint: true) do
        broker.save
        catalog_hash = broker.client.catalog
        catalog = VCAP::CloudController::ServiceBroker::V2::Catalog.new(broker, catalog_hash)
        raise VCAP::Errors::ServiceBrokerCatalogInvalid.new(catalog.error_text) unless catalog.valid?
        catalog.sync_services_and_plans
      end
      self
    end

    def errors
      broker.errors
    end
  end
end
