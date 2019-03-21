module VCAP::CloudController
  class ManagedServiceInstanceListFetcher
    def fetch(message:, readable_space_guids:)
      source_space_instance_dataset = ManagedServiceInstance.select_all(ServiceInstance.table_name).
                                      join(Space.table_name, id: :space_id, guid: readable_space_guids)

      shared_instance_dataset = ManagedServiceInstance.select_all(ServiceInstance.table_name).
                                join(:service_instance_shares, service_instance_guid: :guid, target_space_guid: readable_space_guids)

      dataset = source_space_instance_dataset.union(shared_instance_dataset, alias: :service_instances)

      filter(dataset, message)
    end

    def fetch_all(message:)
      dataset = ManagedServiceInstance.dataset
      filter(dataset, message)
    end

    private

    def filter(dataset, message)
      if message.requested?(:names)
        dataset = dataset.where(service_instances__name: message.names)
      end

      if message.requested?(:space_guids)
        dataset = dataset.select_all(ServiceInstance.table_name).
                  join_table(:inner, Space.table_name, { id: Sequel.qualify(:service_instances, :space_id), guid: message.space_guids })
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: ServiceInstanceLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: ServiceInstance,
        )
      end

      dataset
    end
  end
end
