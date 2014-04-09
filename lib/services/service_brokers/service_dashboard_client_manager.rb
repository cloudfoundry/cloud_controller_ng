module VCAP::Services::ServiceBrokers
  class ServiceDashboardClientManager
    attr_reader :errors, :service_broker

    def initialize(service_broker)
      @service_broker = service_broker
      @errors         = VCAP::Services::ValidationErrors.new

      @client_manager = VCAP::Services::UAA::UaaClientManager.new
      @differ         = ServiceDashboardClientDiffer.new(service_broker)
    end

    def synchronize_clients_with_catalog(catalog)
      return true unless cc_configured_to_modify_uaa_clients?

      requested_clients         = catalog.services.map(&:dashboard_client).compact
      client_ids_already_in_uaa = get_client_ids_already_in_uaa(requested_clients)
      unclaimable_ids           = get_client_ids_that_cannot_be_claimed(client_ids_already_in_uaa)

      if !unclaimable_ids.empty?
        populate_uniqueness_errors(catalog, unclaimable_ids)
        return false
      end

      available_clients = client_ids_already_in_uaa.map do |id|
        VCAP::CloudController::ServiceDashboardClient.find_client_by_uaa_id(id)
      end

      broker_claimed_clients = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker).all
      existing_clients       = (broker_claimed_clients + available_clients).uniq

      changeset = differ.create_changeset(requested_clients, existing_clients)

      claim_clients_and_update_uaa(changeset)

      true
    end

    def remove_clients_for_broker
      return unless cc_configured_to_modify_uaa_clients?

      requested_clients = [] # request no clients
      existing_clients  = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker)
      changeset         = differ.create_changeset(requested_clients, existing_clients)

      claim_clients_and_update_uaa(changeset)
    end

    private

    attr_reader :client_manager, :differ

    def claim_clients_and_update_uaa(changeset)
      begin
        service_broker.db.transaction(savepoint: true) do
          changeset.each(&:db_command)
          client_manager.modify_transaction(changeset)
        end
      rescue VCAP::Services::UAA::UaaError => e
        raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerDashboardClientFailure", e.message)
      end
    end

    def get_client_ids_already_in_uaa(requested_clients)
      requested_client_ids   = requested_clients.map { |c| c['id'] }
      clients_already_in_uaa = client_manager.get_clients(requested_client_ids).map { |c| c['client_id'] }
      clients_already_in_uaa
    end

    def get_client_ids_that_cannot_be_claimed(clients)
      unclaimable_ids = []
      clients.each do |id|
        claimable = VCAP::CloudController::ServiceDashboardClient.client_can_be_claimed_by_broker?(id, service_broker)

        if !claimable
          unclaimable_ids << id
        end
      end
      unclaimable_ids
    end

    def populate_uniqueness_errors(catalog, non_unique_ids)
      catalog.services.each do |service|
        if service.dashboard_client && non_unique_ids.include?(service.dashboard_client['id'])
          errors.add_nested(service).add('Service dashboard client id must be unique')
        end
      end
    end

    def cc_configured_to_modify_uaa_clients?
      uaa_client = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]
      uaa_client && uaa_client_secret
    end
  end
end
