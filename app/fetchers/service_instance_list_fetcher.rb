require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class ServiceInstanceListFetcher < BaseListFetcher
    class << self
      def fetch(message, omniscient: false, readable_spaces_dataset: nil, eager_loaded_associations: [])
        dataset = ServiceInstance.dataset.eager(eager_loaded_associations).
                  join(:spaces, id: Sequel[:service_instances][:space_id]).
                  left_join(:service_instance_shares, service_instance_guid: Sequel[:service_instances][:guid])

        unless omniscient
          dataset = dataset.where do
            (Sequel[:spaces][:guid] =~ readable_spaces_dataset) |
              (Sequel[:service_instance_shares][:target_space_guid] =~ readable_spaces_dataset)
          end
        end

        if message.requested?(:service_plan_names) || message.requested?(:service_plan_guids)
          dataset = dataset.left_join(:service_plans, id: Sequel[:service_instances][:service_plan_id])
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

        if message.requested?(:organization_guids)
          spaces_in_orgs = Space.dataset.select(:spaces__guid).
                           join(:organizations, id: Sequel[:spaces][:organization_id]).
                           where(Sequel[:organizations][:guid] =~ message.organization_guids)

          dataset = dataset.where do
            (Sequel[:spaces][:guid] =~ spaces_in_orgs) |
              (Sequel[:service_instance_shares][:target_space_guid] =~ spaces_in_orgs)
          end
        end

        if message.requested?(:space_guids)
          dataset = dataset.where do
            (Sequel[:spaces][:guid] =~ message.space_guids) |
              (Sequel[:service_instance_shares][:target_space_guid] =~ message.space_guids)
          end
        end

        if message.requested?(:service_plan_guids)
          dataset = dataset.where { Sequel[:service_plans][:guid] =~ message.service_plan_guids }
        end

        if message.requested?(:service_plan_names)
          dataset = dataset.where { Sequel[:service_plans][:name] =~ message.service_plan_names }
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServiceInstanceLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: ServiceInstance,
          )
        end

        super(message, dataset, ServiceInstance)
      end
    end
  end
end
