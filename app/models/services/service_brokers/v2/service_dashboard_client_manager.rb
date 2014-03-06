require 'models/services/service_brokers/v2/uaa_client_manager'
require 'models/services/validation_errors'

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
      existing_clients    = client_manager.get_clients(requested_client_ids)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      clients_to_create = requested_client_ids - existing_client_ids

      services_whose_requested_clients_exist = find_catalog_services_with_existing_uaa_clients(services_requesting_dashboard_client, existing_clients)

      return false unless validate_existing_clients_match_existing_services(services_whose_requested_clients_exist)

      services_requesting_dashboard_client.each do |service|
        if clients_to_create.include?(service.dashboard_client['id'])
          client_manager.create(service.dashboard_client)
          VCAP::CloudController::ServiceDashboardClient.claim_client_for_service(
            service.dashboard_client['id'],
            service.broker_provided_id
          )
        end
      end
      true
    end

    private

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end

    def validate_existing_clients_match_existing_services(services_whose_requested_clients_exist)
      return true if services_whose_requested_clients_exist.empty?

      services_whose_requested_clients_exist.each do |catalog_service|
        unless VCAP::CloudController::ServiceDashboardClient.client_claimed_by_service?(
          catalog_service.dashboard_client['id'],
          catalog_service.broker_provided_id
        )
          errors.add_nested(catalog_service).add('Service dashboard client ids must be unique')
        end
      end
      return errors.empty?
    end

    def find_catalog_services_with_existing_uaa_clients(catalog_services, existing_clients)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      catalog_services.select { |s| existing_client_ids.include?(s.dashboard_client['id']) }
    end
  end
end
