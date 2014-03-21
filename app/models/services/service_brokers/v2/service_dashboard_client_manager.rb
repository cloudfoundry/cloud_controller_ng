require 'models/services/service_brokers/v2/uaa_client_manager'
require 'models/services/service_brokers/v2/service_dashboard_client_differ'
require 'models/services/validation_errors'

module VCAP::CloudController::ServiceBrokers::V2
  class ServiceDashboardClientManager
    attr_reader :catalog,  :errors, :service_broker

    def initialize(catalog, service_broker)
      @catalog        = catalog
      @service_broker = service_broker
      @errors         = VCAP::CloudController::ValidationErrors.new

      @services_requesting_dashboard_client = catalog.services.select(&:dashboard_client)
      @client_manager                       = UaaClientManager.new
      @differ                               = ServiceDashboardClientDiffer.new(service_broker, client_manager)
    end

    def synchronize_clients
      return true unless cc_configured_to_modify_uaa_clients?

      validate_requested_clients_are_available!
      return false unless errors.empty?

      clients_claimed_by_broker = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker)
      changeset = differ.create_changeset(services_requesting_dashboard_client, clients_claimed_by_broker)
      changeset.each(&:apply!)

      true
    end

    private

    attr_reader :client_manager, :differ, :services_requesting_dashboard_client

    def validate_requested_clients_are_available!
      existing_clients    = client_manager.get_clients(requested_client_ids)
      existing_client_ids = existing_clients.map { |client| client['client_id'] }

      services_whose_requested_clients_exist = services_requesting_dashboard_client.select { |s|
        existing_client_ids.include?(s.dashboard_client['id'])
      }

      services_whose_requested_clients_are_not_claimed_by_its_broker = services_whose_requested_clients_exist.reject do |service|
        VCAP::CloudController::ServiceDashboardClient.client_claimed_by_broker?(
          service.dashboard_client['id'],
          service_broker
        )
      end

      services_whose_requested_clients_are_not_claimed_by_its_broker.each do |catalog_service|
        errors.add_nested(catalog_service).add('Service dashboard client ids must be unique')
      end
    end

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end

    def cc_configured_to_modify_uaa_clients?
      uaa_client = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]
      uaa_client && uaa_client_secret
    end
  end
end
