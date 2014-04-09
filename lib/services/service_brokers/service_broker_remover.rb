module VCAP::Services::ServiceBrokers
  class ServiceBrokerRemover
    attr_reader :broker, :client_manager

    def initialize(broker)
      @broker = broker
      @client_manager = ServiceDashboardClientManager.new(broker)
    end

    def execute!
      client_manager.remove_clients_for_broker
      broker.destroy
    end
  end
end
