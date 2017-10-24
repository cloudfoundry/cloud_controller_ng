module VCAP::CloudController
  class ServiceInstanceListFetcher
    def fetch(message:, space_guids:)
      dataset = ServiceInstance.select_all(ServiceInstance.table_name).
                join(Space.table_name, id: :space_id, guid: space_guids)

      filter(dataset, message)
    end

    def fetch_all(message:)
      dataset = ServiceInstance.dataset
      filter(dataset, message)
    end

    private

    def filter(dataset, message)
      if message.requested?(:names)
        dataset = dataset.where(service_instances__name: message.names)
      end

      dataset
    end
  end
end
