module VCAP::CloudController
  class ServiceInstanceListFetcher
    def fetch(message:, space_guids:)
      source_space_instance_dataset = ServiceInstance.select_all(ServiceInstance.table_name).
                                      join(Space.table_name, id: :space_id, guid: space_guids)

      shared_instance_dataset = ServiceInstance.select_all(ServiceInstance.table_name).
                                join(:service_instance_shares, service_instance_guid: :guid, target_space_guid: space_guids)

      dataset = source_space_instance_dataset.union(shared_instance_dataset, alias: :service_instances)

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
