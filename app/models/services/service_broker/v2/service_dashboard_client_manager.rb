require 'models/services/service_broker/v2/uaa_client_manager'

module VCAP::CloudController::ServiceBroker::V2
  class ServiceDashboardClientManager
    attr_reader :catalog, :client_manager, :services_requesting_dashboard_client

    def initialize(catalog)
      @catalog                              = catalog
      @client_manager                       = UaaClientManager.new
      @services_requesting_dashboard_client = catalog.services.select(&:dashboard_client)
    end

    def create_service_dashboard_clients
      existing_clients = client_manager.get_clients(requested_client_ids)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      clients_to_create = requested_client_ids - existing_client_ids

      services_with_existing_clients = find_catalog_services_with_existing_uaa_clients(services_requesting_dashboard_client, existing_clients)

      validate_existing_clients_match_existing_services!(services_with_existing_clients)

      services_requesting_dashboard_client.each do |service|
        client_manager.create(service.dashboard_client) if clients_to_create.include?(service.dashboard_client['id'])
      end
    end

    private

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end

    def validate_existing_clients_match_existing_services!(services_with_existing_clients)
      return if services_with_existing_clients.empty?

      errors_found = false

      services_with_existing_clients.each do |catalog_service|
        db_service = catalog_service.cc_service

        # ensure that the service requesting the existing uaa client is the one that originally created it
        if db_service.nil? || (db_service.sso_client_id != catalog_service.dashboard_client['id'])
          catalog_service.errors << 'Service dashboard client ids must be unique'
          errors_found = true
        end
      end
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", catalog.error_text) if errors_found
    end

    def find_catalog_services_with_existing_uaa_clients(catalog_services, existing_clients)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      catalog_services.select { |s| existing_client_ids.include?(s.dashboard_client['id']) }
    end
  end
end
