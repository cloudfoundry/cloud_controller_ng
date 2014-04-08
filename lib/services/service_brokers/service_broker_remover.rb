module VCAP::Services::ServiceBrokers
  class ServiceBrokerRemover
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def execute!
      delete_dashboard_clients
      broker.destroy
    end

    private

    def delete_dashboard_clients
      differ = ServiceDashboardClientDiffer.new(broker)
      changeset = differ.create_changeset([], clients_claimed_by_broker)

      return if changeset.empty?

      broker.db.transaction(savepoint: true) do
        changeset.each(&:db_command)
        client_manager.modify_transaction(changeset)
      end
    end

    def client_manager
      VCAP::Services::UAA::UaaClientManager.new
    end

    def clients_claimed_by_broker
      VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(broker)
    end
  end
end
