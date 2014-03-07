require 'models/services/service_brokers/v2/uaa_client_manager'
require 'models/services/validation_errors'
require 'models/services/service_brokers/v2/service_dashboard_client_differ'

module VCAP::CloudController::ServiceBrokers::V2
  class ServiceDashboardClientManager
    attr_reader :catalog, :client_manager, :errors, :service_broker, :services_requesting_dashboard_client

    def initialize(catalog, service_broker)
      @catalog                              = catalog
      @client_manager                       = UaaClientManager.new
      @services_requesting_dashboard_client = catalog.services.select(&:dashboard_client)
      @errors                               = VCAP::CloudController::ValidationErrors.new
      @service_broker                       = service_broker
    end

    def synchronize_clients
      validate_requested_clients_are_available!
      return false unless errors.empty?

      changeset = ServiceDashboardClientDiffer.create_changeset(services_requesting_dashboard_client, client_manager)
      changeset.each(&:apply!)

      true
    end

    private

    def validate_requested_clients_are_available!
      existing_clients    = client_manager.get_clients(requested_client_ids)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      services_whose_requested_clients_exist = services_requesting_dashboard_client.select { |s|
        existing_client_ids.include?(s.dashboard_client['id'])
      }

      services_whose_requested_clients_exist.each do |catalog_service|
        errors.add_nested(catalog_service).add('Service dashboard client ids must be unique')
      end
    end

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end


  end
end
