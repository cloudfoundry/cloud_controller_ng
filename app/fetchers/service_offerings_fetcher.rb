module VCAP::CloudController
  class ServiceOfferingsFetcher
    class << self
      def fetch(service_offering_guid)
        service_offering = Service.where(guid: service_offering_guid).eager(:service_plans, :service_broker).first
        return [nil, nil, false] if service_offering.nil?

        public = service_offering.service_plans.any?(&:public)
        space = service_offering.service_broker.space

        [service_offering, space, public]
      end
    end
  end
end
