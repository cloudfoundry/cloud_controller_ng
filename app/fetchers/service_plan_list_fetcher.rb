require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServicePlanListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_spaces_query: nil, readable_orgs_query: nil, eager_loaded_associations: [])
        dataset = select_readable(
          ServicePlan.dataset.eager(eager_loaded_associations),
          message,
          omniscient: omniscient,
          readable_orgs_query: readable_orgs_query,
          readable_spaces_query: readable_spaces_query,
        )

        filter(message, dataset).select_all(:service_plans).distinct
      end

      private

      def join_services(dataset)
        join(dataset, :inner, :services, id: Sequel[:service_plans][:service_id])
      end

      def filter(message, dataset)
        if message.requested?(:available)
          dataset = dataset.where { Sequel[:service_plans][:active] =~ message.available? }
        end

        if message.requested?(:names)
          dataset = dataset.where { Sequel[:service_plans][:name] =~ message.names }
        end

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
