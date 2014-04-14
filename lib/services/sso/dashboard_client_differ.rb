module VCAP::Services::SSO
  class DashboardClientDiffer
    def initialize(broker)
      @broker = broker
    end

    def create_db_changeset(requested_clients, existing_cc_clients)
      requested_ids = requested_clients.map{|client| client.fetch('id')}

      create_and_update_commands = requested_clients.map do |requested_client|
        Commands::ClaimClientCommand.new(requested_client.fetch('id'), broker)
      end

      delete_commands = existing_cc_clients.map do |client|
        client_id = client.uaa_id
        unless requested_ids.include?(client_id)
          Commands::UnclaimClientCommand.new(client_id)
        end
      end.compact

      create_and_update_commands + delete_commands
    end

    def create_uaa_changeset(requested_clients, existing_uaa_clients)
      requested_ids = requested_clients.map{|client| client.fetch('id')}

      create_and_update_commands = requested_clients.map do |requested_client|
        existing_uaa_client = existing_uaa_clients.detect { |client| client == requested_client.fetch('id') }

        if existing_uaa_client
          Commands::UpdateClientCommand.new(requested_client)
        else
          Commands::CreateClientCommand.new(requested_client)
        end
      end

      delete_commands = existing_uaa_clients.map do |client_id|
        unless requested_ids.include?(client_id)
          Commands::DeleteClientCommand.new(client_id)
        end
      end.compact

      create_and_update_commands + delete_commands
    end

    private

    attr_reader :broker
  end
end
