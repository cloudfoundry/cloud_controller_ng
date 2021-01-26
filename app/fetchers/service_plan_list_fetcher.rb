require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServicePlanListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_space_guids: [], readable_org_guids: [], eager_loaded_associations: [])
        dataset = ServicePlan.dataset.eager(eager_loaded_associations)

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
          select_all(:service_plans).
          distinct
      end

      private

      def join_tables(dataset, message, omniscient)
        need_all_parent_tables = !omniscient || visibility_filter?(message)
        filter_properties = [
          :service_broker_guids,
          :service_broker_names,
          :service_offering_guids,
          :service_offering_names,
          :broker_catalog_ids
        ]

        need_broker_and_offering_tables = filter_properties.any? { |filter| message.requested?(filter) }

        if need_all_parent_tables
          dataset = join_all_parent_tables(dataset.join(:services, id: Sequel[:service_plans][:service_id]))
        elsif need_broker_and_offering_tables
          dataset = dataset.
                    join(:services, id: Sequel[:service_plans][:service_id]).
                    join(:service_brokers, id: Sequel[:services][:service_broker_id])
        end

        if message.requested?(:service_instance_guids)
          dataset = dataset.join(Sequel[:service_instances], service_plan_id: Sequel[:service_plans][:id])
        end

        dataset
      end

      def filter(message, dataset)
        if message.requested?(:available)
          dataset = dataset.where { Sequel[:service_plans][:active] =~ message.available? }
        end

        if message.requested?(:names)
          dataset = dataset.where { Sequel[:service_plans][:name] =~ message.names }
        end

        if message.requested?(:service_offering_guids)
          dataset = dataset.where { Sequel[:services][:guid] =~ message.service_offering_guids }
        end

        if message.requested?(:service_offering_names)
          dataset = dataset.where { Sequel[:services][:label] =~ message.service_offering_names }
        end

        if message.requested?(:service_instance_guids)
          dataset = dataset.where { Sequel[:service_instances][:guid] =~ message.service_instance_guids }
        end

        if message.requested?(:broker_catalog_ids)
          dataset = dataset.where { Sequel[:service_plans][:unique_id] =~ message.broker_catalog_ids }
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServicePlanLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: ServicePlan,
          )
        end

        super(message, dataset, ServicePlan)
      end
    end
  end
end
