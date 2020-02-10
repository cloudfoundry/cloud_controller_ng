require 'set'

module VCAP::CloudController
  class ServicePlanListFetcher
    def fetch(message, omniscient: false, readable_space_guids: [], readable_org_guids: [])
      dataset = ServicePlan.dataset

      dataset = join_tables(dataset, message, omniscient)

      dataset = select_readable_plans(
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

      dataset = filter(dataset, message)

      dataset.
        select_all(:service_plans).
        distinct
    end

    private

    def join_tables(dataset, message, omniscient)
      need_all_tables = !omniscient || [:space_guids, :organization_guids].any? { |filter| message.requested?(filter) }
      need_broker_and_offering_tables = [:service_broker_guids, :service_offering_guids, :broker_catalog_ids].any? { |filter| message.requested?(filter) }

      if need_all_tables

        dataset = dataset.
                  join(:services, id: Sequel[:service_plans][:service_id]).
                  join(:service_brokers, id: Sequel[:services][:service_broker_id]).
                  left_join(Sequel[:spaces].as(:broker_spaces), id: Sequel[:service_brokers][:space_id]).
                  left_join(Sequel[:organizations].as(:broker_orgs), id: Sequel[:broker_spaces][:organization_id]).
                  left_join(:service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id]).
                  left_join(Sequel[:organizations].as(:plan_orgs), id: Sequel[:service_plan_visibilities][:organization_id]).
                  left_join(Sequel[:spaces].as(:plan_spaces), organization_id: Sequel[:plan_orgs][:id])

      elsif need_broker_and_offering_tables

        dataset = dataset.
                  join(:services, id: Sequel[:service_plans][:service_id]).
                  join(:service_brokers, id: Sequel[:services][:service_broker_id])

      end
      dataset
    end

    def select_readable_plans(dataset, omniscient: false, readable_space_guids: [], readable_org_guids: [])
      if readable_org_guids.any?
        dataset = dataset.where do
          (Sequel[:service_plans][:public] =~ true) |
            (Sequel[:plan_orgs][:guid] =~ readable_org_guids) |
            (Sequel[:broker_spaces][:guid] =~ readable_space_guids)
        end
      elsif !omniscient
        dataset = dataset.where { Sequel[:service_plans][:public] =~ true }
      end

      dataset
    end

    def filter_orgs(dataset, organization_guids)
      dataset.where do
        (Sequel[:service_plans][:public] =~ true) |
          (Sequel[:plan_orgs][:guid] =~ organization_guids) |
          (Sequel[:broker_orgs][:guid] =~ organization_guids)
      end
    end

    def filter_spaces(dataset, filtered_space_guids:, readable_space_guids:, omniscient:)
      space_guids = authorized_space_guids(
        space_guids: filtered_space_guids,
        readable_space_guids: readable_space_guids,
        omniscient: omniscient,
      )

      dataset.where do
        (Sequel[:service_plans][:public] =~ true) |
          (Sequel[:plan_spaces][:guid] =~ space_guids) |
          (Sequel[:broker_spaces][:guid] =~ space_guids)
      end
    end

    def filter(dataset, message)
      if message.requested?(:names)
        dataset = dataset.where { Sequel[:service_plans][:name] =~ message.names }
      end

      if message.requested?(:available)
        dataset = dataset.where { Sequel[:service_plans][:active] =~ message.available? }
      end

      if message.requested?(:service_broker_guids)
        dataset = dataset.where { Sequel[:service_brokers][:guid] =~ message.service_broker_guids }
      end

      if message.requested?(:service_offering_guids)
        dataset = dataset.where { Sequel[:services][:guid] =~ message.service_offering_guids }
      end

      if message.requested?(:broker_catalog_ids)
        dataset = dataset.where { Sequel[:services][:unique_id] =~ message.broker_catalog_ids }
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: ServicePlanLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: ServicePlan,
        )
      end

      dataset
    end

    def authorized_space_guids(space_guids: [], readable_space_guids: [], omniscient: false)
      return space_guids if omniscient

      (Set.new(readable_space_guids) & Set.new(space_guids)).to_a
    end
  end
end
