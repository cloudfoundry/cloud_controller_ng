require 'models/services/service_brokers/v2/uaa_client_manager'
require 'models/services/service_brokers/v2/service_dashboard_client_differ'

module VCAP::CloudController
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
      differ = ServiceBrokers::V2::ServiceDashboardClientDiffer.new(broker, client_manager)
      changeset = differ.create_changeset([], clients_claimed_by_broker)
      changeset.each(&:apply!)
    end

    def client_manager
      ServiceBrokers::V2::UaaClientManager.new
    end

    def clients_claimed_by_broker
      ServiceDashboardClient.find_clients_claimed_by_broker(broker)
    end
  end
end
