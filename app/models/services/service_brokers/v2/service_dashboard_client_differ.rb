require 'models/services/service_brokers/v2/create_client_command'

module VCAP::CloudController::ServiceBrokers::V2
  module ServiceDashboardClientDiffer
    def self.create_changeset(catalog_services, uaa_client)
      catalog_services.map do |service|
        CreateClientCommand.new(service.dashboard_client, uaa_client)
      end
    end
  end
end
