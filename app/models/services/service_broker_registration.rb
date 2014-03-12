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

      catalog = ServiceBrokers::V2::Catalog.new(broker, broker.client.catalog)
      raise_humanized_exception(catalog.errors) unless catalog.valid?
      broker.db.transaction(savepoint: true) do
        broker.save
        catalog.sync_services_and_plans
      end

      begin
        manager = ServiceBrokers::V2::ServiceDashboardClientManager.new(catalog, broker)

        successfully_synced = manager.synchronize_clients

        raise_humanized_exception(manager.errors) unless successfully_synced
      rescue => e
        broker.destroy
        raise e
      end

      return self
    end

    def errors
      broker.errors
    end

    private

    def formatter
      @formatter ||= ServiceBrokers::V2::ValidationErrorsFormatter.new
    end

    def raise_humanized_exception(errors)
      humanized_message = formatter.format(errors)
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", humanized_message)
    end
  end
end
