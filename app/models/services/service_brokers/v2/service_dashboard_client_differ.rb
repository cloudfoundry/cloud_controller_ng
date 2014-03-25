require 'models/services/service_brokers/v2/create_client_command'
require 'models/services/service_brokers/v2/update_client_command'
require 'models/services/service_brokers/v2/delete_client_command'

module VCAP::CloudController::ServiceBrokers::V2
  class ServiceDashboardClientDiffer
    def initialize(broker, client_manager)
      @broker = broker
      @client_manager = client_manager
    end

    def create_changeset(catalog_services, existing_clients)
      requested_clients = catalog_services.map(&:dashboard_client)
      requested_ids = requested_clients.map{|client| client.fetch('id')}

      create_and_update_commands = requested_clients.map do |requested_client|
        existing_client = existing_clients.detect {|client|
          client.uaa_id == requested_client.fetch('id')
        }
        if existing_client
          UpdateClientCommand.new(
            client_attrs: requested_client,
            client_manager: client_manager,
            service_broker: broker,
          )
        else
          CreateClientCommand.new(
            client_attrs: requested_client,
            client_manager: client_manager,
            service_broker: broker,
          )
        end
      end

      delete_commands = existing_clients.map do |client|
        client_id = client.uaa_id
        unless requested_ids.include?(client_id)
          DeleteClientCommand.new(
            client_id: client_id,
            client_manager: client_manager
          )
        end
      end.compact

      create_and_update_commands + delete_commands
    end

    private

    attr_reader :broker, :client_manager
  end
end
