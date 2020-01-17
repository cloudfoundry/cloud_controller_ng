module VCAP::CloudController
  class ServiceOfferingFetcher
    class << self
      def fetch(service_offering_guid)
        Service.where(guid: service_offering_guid).eager(:service_plans, :service_broker).first
      end
    end
  end
end
