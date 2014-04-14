module VCAP::Services::ServiceBrokers
  class ServiceBrokerRemover
    attr_reader :broker, :client_manager

    def initialize(broker)
      @broker = broker
      @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker)
    end

    def execute!
      client_manager.remove_clients_for_broker
      broker.destroy
    end
  end
end
