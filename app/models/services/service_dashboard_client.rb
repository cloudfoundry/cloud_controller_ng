module VCAP::CloudController
  class ServiceDashboardClient < Sequel::Model

    def self.claim_client_for_service(uaa_id, claiming_service_id)
      create(uaa_id: uaa_id, service_id_on_broker: claiming_service_id)
      nil
    end

    def self.client_claimed_by_service?(uaa_id, service_id_on_broker)
      where(service_id_on_broker: service_id_on_broker, uaa_id: uaa_id).any?
    end

    def validate
      validates_presence :service_id_on_broker
      validates_presence :uaa_id

      validates_unique :service_id_on_broker
      validates_unique :uaa_id
    end
  end
end
