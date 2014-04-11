module VCAP::Services::ServiceBrokers
  class ServiceDashboardClientDiffer
    def initialize(broker)
      @broker = broker
    end

    def create_changeset(requested_clients, existing_cc_clients, existing_uaa_clients=[])
      requested_ids = requested_clients.map{|client| client.fetch('id')}

      create_and_update_commands = requested_clients.map do |requested_client|

        existing_cc_client  = existing_cc_clients.detect { |client| client.uaa_id == requested_client.fetch('id') }
        existing_uaa_client = existing_uaa_clients.detect { |client| client == requested_client.fetch('id') }

        if existing_cc_client && existing_uaa_client
          VCAP::Services::UAA::UpdateClientCommand.new(
            client_attrs: requested_client,
            service_broker: broker,
          )
        else
          VCAP::Services::UAA::CreateClientCommand.new(
            client_attrs: requested_client,
            service_broker: broker,
          )
        end
      end

      delete_commands = existing_cc_clients.map do |client|
        client_id = client.uaa_id
        unless requested_ids.include?(client_id)
          VCAP::Services::UAA::DeleteClientCommand.new(client_id)
        end
      end.compact

      create_and_update_commands + delete_commands
    end

    private

    attr_reader :broker
  end
end
