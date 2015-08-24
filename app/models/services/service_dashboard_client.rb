module VCAP::CloudController
  module DashboardClientValidation
    def validate
      validates_presence :uaa_id
      validates_unique :uaa_id
    end
  end

  module DashboardClient
    def find_client_by_uaa_id(uaa_id)
      where(uaa_id: uaa_id).first
    end

    def release_client(uaa_id)
      where(uaa_id: uaa_id).delete
    end

    def claim_client(uaa_id, resource)
      return if client_claimed?(uaa_id, resource)

      unclaimed_client = unclaimed_client_with_uaa_id(uaa_id)

      if unclaimed_client.nil?
        create_resource(resource, uaa_id)
      else
        update_resource(resource, unclaimed_client)
      end

      nil
    end

    def client_claimed?(uaa_id, resource)
      get_client(resource.id, uaa_id).any?
    end

    def unclaimed_client_with_uaa_id(uaa_id)
      get_client(nil, uaa_id).first
    end
  end

  class ServiceDashboardClient < Sequel::Model
    many_to_one :service_broker

    include DashboardClientValidation
    extend DashboardClient

    class << self
      def find_claimed_client(broker)
        where(service_broker_id: broker.id)
      end

      private

      def get_client(broker_id, uaa_id)
        where(service_broker_id: broker_id, uaa_id: uaa_id)
      end

      def update_resource(broker, unclaimed_client)
        unclaimed_client.update(service_broker_id: broker.id)
      end

      def create_resource(broker, uaa_id)
        create(uaa_id: uaa_id, service_broker: broker)
      end
    end
  end

  class ServiceInstanceDashboardClient < Sequel::Model
    many_to_one :managed_service_instance

    include DashboardClientValidation
    extend DashboardClient

    class << self
      def find_claimed_client(instance)
        where(managed_service_instance_id: instance.id)
      end

      private

      def get_client(instance_id, uaa_id)
        where(managed_service_instance_id: instance_id, uaa_id: uaa_id)
      end

      def update_resource(instance, unclaimed_client)
        unclaimed_client.update(managed_service_instance_id: instance.id)
      end

      def create_resource(instance, uaa_id)
        create(uaa_id: uaa_id, managed_service_instance: instance)
      end
    end
  end
end
