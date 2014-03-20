require 'models/services/service_brokers/v2/service_dashboard_client_manager'
require 'models/services/service_brokers/v2/validation_errors_formatter'

module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def create
      return unless broker.valid?
      validate_catalog!
      broker.save

      begin
        synchronize_dashboard_clients!

        broker.db.transaction(savepoint: true) do
          catalog.sync_services_and_plans
        end
      rescue => e
        broker.destroy
        raise e
      end
      return self
    end

    def update
      return unless broker.valid?
      validate_catalog!
      synchronize_dashboard_clients!

      broker.db.transaction(savepoint: true) do
        broker.save
        catalog.sync_services_and_plans
      end
      return self
    end

    def errors
      broker.errors
    end

    private

    def synchronize_dashboard_clients!
      unless manager.synchronize_clients
        raise_humanized_exception(manager.errors)
      end
    end

    def validate_catalog!
      raise_humanized_exception(catalog.errors) unless catalog.valid?
    end

    def manager
      @manager ||= ServiceBrokers::V2::ServiceDashboardClientManager.new(catalog, broker)
    end

    def catalog
      @catalog ||= ServiceBrokers::V2::Catalog.new(broker, broker.client.catalog)
    end

    def formatter
      @formatter ||= ServiceBrokers::V2::ValidationErrorsFormatter.new
    end

    def raise_humanized_exception(errors)
      humanized_message = formatter.format(errors)
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", humanized_message)
    end
  end
end
