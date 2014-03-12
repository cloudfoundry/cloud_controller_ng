module VCAP::CloudController
  class ServiceDashboardClient < Sequel::Model
    many_to_one :service_broker

    def self.find_clients_claimed_by_broker(broker)
      where(service_broker_id: broker.id)
    end

    def self.claim_client_for_broker(uaa_id, claiming_broker)
      create(uaa_id: uaa_id, service_broker: claiming_broker)
      nil
    end

    def self.client_claimed_by_broker?(uaa_id, broker)
      where(service_broker_id: broker.id, uaa_id: uaa_id).any?
    end

    def validate
      validates_presence :service_broker
      validates_presence :uaa_id

      validates_unique :uaa_id
    end
  end
end
