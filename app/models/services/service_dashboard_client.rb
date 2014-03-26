module VCAP::CloudController
  class ServiceDashboardClient < Sequel::Model
    many_to_one :service_broker

    def self.find_clients_claimed_by_broker(broker)
      where(service_broker_id: broker.id)
    end

    def self.claim_client_for_broker(uaa_id, claiming_broker)
      return if client_claimed_by_broker?(uaa_id, claiming_broker)

      unclaimed_client = unclaimed_client_with_uaa_id(uaa_id)

      if unclaimed_client.nil?
        create(uaa_id: uaa_id, service_broker: claiming_broker)
      else
        unclaimed_client.update(service_broker_id: claiming_broker.id)
      end

      nil
    end

    def self.client_claimed_by_broker?(uaa_id, broker)
      where(service_broker_id: broker.id, uaa_id: uaa_id).any?
    end

    def self.client_can_be_claimed_by_broker?(uaa_id, broker)
      client_claimed_by_broker?(uaa_id, broker) || client_not_claimed_by_any_broker?(uaa_id)
    end

    def self.remove_claim_on_client(uaa_id)
      where(uaa_id: uaa_id).delete
    end

    def self.find_client_by_uaa_id(uaa_id)
      where(uaa_id: uaa_id).first
    end

    def validate
      validates_presence :uaa_id
      validates_unique :uaa_id
    end

    private

    def self.client_not_claimed_by_any_broker?(uaa_id)
      !(unclaimed_client_with_uaa_id(uaa_id).nil?)
    end

    def self.unclaimed_client_with_uaa_id(uaa_id)
      where(service_broker_id: nil, uaa_id: uaa_id).first
    end
  end
end
