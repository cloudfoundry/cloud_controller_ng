module VCAP::CloudController
  class ServiceDashboardClient < Sequel::Model
    many_to_one :service_broker

    def validate
      validates_presence :uaa_id
      validates_unique :uaa_id
    end

    class << self
      def find_claimed_client(broker)
        where(service_broker_id: broker.id)
      end

      def find_client_by_uaa_id(uaa_id)
        where(uaa_id: uaa_id).first
      end

      def claim_client(uaa_id, broker)
        return if client_claimed?(uaa_id, broker)

        unclaimed_client = find_unclaimed_client(uaa_id)

        if unclaimed_client.nil?
          create_client(broker, uaa_id)
        else
          update_client(broker, unclaimed_client)
        end

        nil
      end

      def release_client(uaa_id)
        where(uaa_id: uaa_id).delete
      end

      private

      def create_client(broker, uaa_id)
        create(uaa_id: uaa_id, service_broker: broker)
      end

      def update_client(broker, unclaimed_client)
        unclaimed_client.update(service_broker_id: broker.id)
      end

      def client_claimed?(uaa_id, broker)
        where(service_broker_id: broker.id, uaa_id: uaa_id).any?
      end

      def find_unclaimed_client(uaa_id)
        where(service_broker_id: nil, uaa_id: uaa_id).first
      end
    end
  end
end
