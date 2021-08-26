module VCAP::CloudController
  class ServiceOfferingFetcher
    class << self
      def fetch(service_offering_guid)
        Service.where(guid: service_offering_guid).first
      end
    end
  end
end
