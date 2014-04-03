module VCAP::Services::ServiceBrokers
  class ServiceBrokerRemoval
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
      differ = ServiceDashboardClientDiffer.new(broker, client_manager)
      changeset = differ.create_changeset([], clients_claimed_by_broker)
      changeset.each(&:apply!)
    end

    def client_manager
      VCAP::Services::UAA::UaaClientManager.new
    end

    def clients_claimed_by_broker
      VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(broker)
    end
  end
end
