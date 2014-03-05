require 'models/services/service_brokers/v2/uaa_client_manager'
require 'models/services/validation_errors'

module VCAP::CloudController::ServiceBrokers::V2
  class ServiceDashboardClientManager
    attr_reader :catalog, :client_manager, :services_requesting_dashboard_client, :errors

    def initialize(catalog)
      @catalog                              = catalog
      @client_manager                       = UaaClientManager.new
      @services_requesting_dashboard_client = catalog.services.select(&:dashboard_client)
      @errors                               = VCAP::CloudController::ValidationErrors.new
    end

    def create_service_dashboard_clients
      existing_clients    = client_manager.get_clients(requested_client_ids)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      clients_to_create = requested_client_ids - existing_client_ids

      services_with_existing_clients = find_catalog_services_with_existing_uaa_clients(services_requesting_dashboard_client, existing_clients)

      return false unless validate_existing_clients_match_existing_services(services_with_existing_clients)

      services_requesting_dashboard_client.each do |service|
        client_manager.create(service.dashboard_client) if clients_to_create.include?(service.dashboard_client['id'])
      end
      true
    end

    private

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end

    def validate_existing_clients_match_existing_services(services_with_existing_clients)
      return true if services_with_existing_clients.empty?

      services_with_existing_clients.each do |catalog_service|
        db_service = catalog_service.cc_service

        # ensure that the service requesting the existing uaa client is the one that originally created it
        if db_service.nil? || (db_service.sso_client_id != catalog_service.dashboard_client['id'])
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
