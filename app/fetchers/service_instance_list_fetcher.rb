module VCAP::CloudController
  class ServiceInstanceListFetcher
    def fetch(message, omniscient: false, readable_space_guids: [])
      dataset = ServiceInstance.dataset.
                join(:spaces, id: Sequel[:service_instances][:space_id]).
                left_join(:service_instance_shares, service_instance_guid: Sequel[:service_instances][:guid])

      if !omniscient
        dataset = dataset.where do
          (Sequel[:spaces][:guid] =~ readable_space_guids) |
          (Sequel[:service_instance_shares][:target_space_guid] =~ readable_space_guids)
        end
      end

      filter(dataset, message).
        select_all(:service_instances).
        distinct
    end

    private

    def filter(dataset, message)
      if message.requested?(:names)
        dataset = dataset.where(service_instances__name: message.names)
      end

      if message.requested?(:type)
        dataset = case message.type
                  when 'managed'
                    dataset.where { (Sequel[:service_instances][:is_gateway_service] =~ true) }
                  when 'user-provided'
                    dataset.where { (Sequel[:service_instances][:is_gateway_service] =~ false) }
                  end
      end

      if message.requested?(:space_guids)
        dataset = dataset.where do
          (Sequel[:spaces][:guid] =~ message.space_guids) |
          (Sequel[:service_instance_shares][:target_space_guid] =~ message.space_guids)
        end
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
