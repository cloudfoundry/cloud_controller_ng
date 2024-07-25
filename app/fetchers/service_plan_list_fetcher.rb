require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServicePlanListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_orgs_query: nil, readable_spaces_query: nil, eager_loaded_associations: [])
        super(ServicePlan,
              message,
              omniscient: omniscient,
              readable_orgs_query: readable_orgs_query,
              readable_spaces_query: readable_spaces_query,
              eager_loaded_associations: eager_loaded_associations.append(:orgs_visibility))
      end

      private

      def filter(message, dataset, klass)
        dataset = dataset.where { Sequel[:service_plans][:active] =~ message.available? } if message.requested?(:available)

        dataset = dataset.where { Sequel[:service_plans][:name] =~ message.names } if message.requested?(:names)

        if message.requested?(:service_offering_guids)
          dataset = join_services(dataset)
          dataset = dataset.where { Sequel[:services][:guid] =~ message.service_offering_guids }
        end

        if message.requested?(:service_offering_names)
          dataset = join_services(dataset)
          dataset = dataset.where { Sequel[:services][:label] =~ message.service_offering_names }
        end

        if message.requested?(:service_instance_guids)
          dataset = join_service_instances(dataset)
          dataset = dataset.where { Sequel[:service_instances][:guid] =~ message.service_instance_guids }
        end

        dataset = dataset.where { Sequel[:service_plans][:unique_id] =~ message.broker_catalog_ids } if message.requested?(:broker_catalog_ids)

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServicePlanLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: ServicePlan
          )
        end

        super
      end

      def join_service_plans(dataset)
        dataset # The ServicePlanListFetcher operates on the :service_plans table, so there is no need for an additional JOIN.
      end

      def join_services(dataset)
        join(dataset, :inner, :services, id: Sequel[:service_plans][:service_id])
      end

      def distinct_union(dataset)
        # The UNIONed :service_plans datasets (permissions granted on org level for plans / permissions
        # granted on space level for brokers / public plans) are already distinct.
        dataset
      end
    end
  end
end
