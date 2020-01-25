module VCAP::CloudController
  class ServiceOfferingUpdate
    class << self
      def update(service_offering, message)
        service_offering.db.transaction do
          MetadataUpdate.update(service_offering, message)
        end

        service_offering
      end
    end
  end
end
