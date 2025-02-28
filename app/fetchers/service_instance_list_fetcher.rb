require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class ServiceInstanceListFetcher < BaseListFetcher
    class << self
      def fetch(message, omniscient: false, readable_spaces_dataset: nil, eager_loaded_associations: [])
        dataset = ServiceInstance.dataset.select_all(:service_instances)

        if omniscient
          dataset = filter(dataset, message)
        else
          # Reduce query complexity by fetching instances and shared instances separately
          instances = dataset.clone.join(:spaces, id: :service_instances__space_id)
          instances = instances.where(Sequel[:spaces][:guid] =~ readable_spaces_dataset)
          instances = filter(instances, message)

          shared_instances = dataset.clone.join(:service_instance_shares, service_instance_guid: :service_instances__guid)
          shared_instances = shared_instances.where(Sequel[:service_instance_shares][:target_space_guid] =~ readable_spaces_dataset)
          shared_instances = filter(shared_instances, message)

          # UNION the two datasets
          dataset = instances.union(shared_instances, all: true, alias: :service_instances)
        end

        dataset = dataset.distinct(:service_instances__id)
        dataset.eager(eager_loaded_associations)
      end

      private

      def filter(dataset, message)
        dataset = filter_names(dataset, message) if message.requested?(:names)
        dataset = filter_type(dataset, message) if message.requested?(:type)
        dataset = filter_organization_guids(dataset, message) if message.requested?(:organization_guids)
        dataset = filter_space_guids(dataset, message) if message.requested?(:space_guids)
        dataset = filter_service_plan_names(dataset, message) if message.requested?(:service_plan_names)
        dataset = filter_service_plan_guids(dataset, message) if message.requested?(:service_plan_guids)
        dataset = filter_label(dataset, message) if message.requested?(:label_selector)

        super(message, dataset, ServiceInstance)
      end

      def filter_names(dataset, message)
        dataset.where(service_instances__name: message.names)
      end

      def filter_type(dataset, message)
        case message.type
        when 'managed'
          dataset.where(Sequel[:service_instances][:is_gateway_service] =~ true)
        when 'user-provided'
          dataset.where(Sequel[:service_instances][:is_gateway_service] =~ false)
        else
          dataset
        end
      end

      def filter_organization_guids(dataset, message)
        dataset = dataset.join(:spaces, id: :service_instances__space_id) unless joined?(dataset, :spaces)
        dataset = dataset.left_join(:service_instance_shares, service_instance_guid: :service_instances__guid) unless joined?(dataset, :service_instance_shares)

        spaces_in_orgs = Space.dataset.select(:spaces__guid).
                         join(:organizations, id: :spaces__organization_id).
                         where(Sequel[:organizations][:guid] =~ message.organization_guids)

        dataset.where((Sequel[:spaces][:guid] =~ spaces_in_orgs) | (Sequel[:service_instance_shares][:target_space_guid] =~ spaces_in_orgs))
      end

      def filter_space_guids(dataset, message)
        dataset = dataset.join(:spaces, id: :service_instances__space_id) unless joined?(dataset, :spaces)
        dataset = dataset.left_join(:service_instance_shares, service_instance_guid: :service_instances__guid) unless joined?(dataset, :service_instance_shares)

        dataset.where((Sequel[:spaces][:guid] =~ message.space_guids) | (Sequel[:service_instance_shares][:target_space_guid] =~ message.space_guids))
      end

      def filter_service_plan_names(dataset, message)
        dataset = dataset.left_join(:service_plans, id: :service_instances__service_plan_id) unless joined?(dataset, :service_plans)

        dataset.where(Sequel[:service_plans][:name] =~ message.service_plan_names)
      end

      def filter_service_plan_guids(dataset, message)
        dataset = dataset.left_join(:service_plans, id: :service_instances__service_plan_id) unless joined?(dataset, :service_plans)

        dataset.where(Sequel[:service_plans][:guid] =~ message.service_plan_guids)
      end

      def filter_label(dataset, message)
        LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: ServiceInstanceLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: ServiceInstance
        )
      end

      def joined?(dataset, table)
        dataset.opts[:join]&.any? { |j| j.table_expr == table }
      end
    end
  end
end
