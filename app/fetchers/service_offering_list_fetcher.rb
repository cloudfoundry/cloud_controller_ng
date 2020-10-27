require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServiceOfferingListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_space_guids: [], readable_org_guids: [])
        dataset = Service.dataset

        dataset = join_tables(dataset, message, omniscient)

        dataset = select_readable(
          dataset,
          omniscient: omniscient,
          readable_org_guids: readable_org_guids,
          readable_space_guids: readable_space_guids,
        )

        if message.requested?(:space_guids)
          dataset = filter_spaces(
            dataset,
            filtered_space_guids: message.space_guids,
            readable_space_guids: readable_space_guids,
            omniscient: omniscient,
          )
        end

        dataset = filter_orgs(dataset, message.organization_guids) if message.requested?(:organization_guids)

        dataset = filter(message, dataset)

        dataset.
          select_all(:services).
          distinct
      end

      def join_tables(dataset, message, omniscient)
        need_all_parent_tables = !omniscient || visibility_filter?(message)

        filter_properties = [
          :service_broker_guids,
          :service_broker_names,
        ]

        need_broker_tables = filter_properties.any? { |filter| message.requested?(filter) }

        if need_all_parent_tables
          dataset = join_all_parent_tables(dataset.left_join(:service_plans, service_id: Sequel[:services][:id]))
        elsif need_broker_tables
          dataset = dataset.join(:service_brokers, id: Sequel[:services][:service_broker_id])
        end

        dataset
      end

      def filter(message, dataset)
        if message.requested?(:names)
          dataset = dataset.where(Sequel[:services][:label] =~ message.names)
        end

        if message.requested?(:available)
          dataset = dataset.where { Sequel[:services][:active] =~ message.available? }
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServiceOfferingLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Service,
          )
        end

        super(message, dataset, Service)
      end
    end
  end
end
