module VCAP::CloudController
  class UsageEventListFetcher
    class << self
      def fetch_all(message, dataset)
        if message.requested?(:types)
          dataset = dataset.where(type: message.types)
        end

        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        if message.requested?(:service_instance_types)
          dataset = dataset.where(service_instance_type: message.service_instance_types)
        end

        if message.requested?(:service_offering_guids)
          dataset = dataset.where(service_guid: message.service_offering_guids)
        end

        dataset
      end
    end
  end
end
