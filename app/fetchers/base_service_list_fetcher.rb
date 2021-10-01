require 'set'
require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class BaseServiceListFetcher < BaseListFetcher
    class << self
      private

      def select_readable(dataset, message, omniscient: false, readable_space_guids: [], readable_org_guids: [])
        if readable_org_guids.any?
          dataset = join_service_plans(dataset)
          dataset = join_plan_orgs(dataset)
          dataset = join_broker_spaces(dataset)

          dataset = dataset.where do
            (Sequel[:service_plans][:public] =~ true) |
              (Sequel[:plan_orgs][:guid] =~ readable_org_guids) |
              (Sequel[:broker_spaces][:guid] =~ readable_space_guids)
          end
        elsif !omniscient
          dataset = join_service_plans(dataset)
          dataset = dataset.where { Sequel[:service_plans][:public] =~ true }
        end

        if message.requested?(:space_guids)
          dataset = filter_spaces(
            dataset,
            filtered_space_guids: message.space_guids,
            readable_space_guids: readable_space_guids,
            omniscient: omniscient,
          )
        end

        dataset = filter_orgs(dataset, message.organization_guids) if message.requested?(:organization_guids)

        dataset
      end

      def filter(message, dataset, klass)
        if message.requested?(:service_broker_guids)
          dataset = join_service_brokers(dataset)
          dataset = dataset.where { Sequel[:service_brokers][:guid] =~ message.service_broker_guids }
        end

        if message.requested?(:service_broker_names)
          dataset = join_service_brokers(dataset)
          dataset = dataset.where { Sequel[:service_brokers][:name] =~ message.service_broker_names }
        end

        super(message, dataset, klass)
      end

      def filter_orgs(dataset, organization_guids)
        dataset = join_service_plans(dataset)
        dataset = join_plan_orgs(dataset)
        dataset = join_broker_orgs(dataset)

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

        dataset = join_service_plans(dataset)
        dataset = join_plan_spaces(dataset)
        dataset = join_broker_spaces(dataset)

        dataset.where do
          (Sequel[:service_plans][:public] =~ true) |
            (Sequel[:plan_spaces][:guid] =~ space_guids) |
            (Sequel[:broker_spaces][:guid] =~ space_guids)
        end
      end

      def authorized_space_guids(space_guids: [], readable_space_guids: [], omniscient: false)
        return space_guids if omniscient

        (Set.new(readable_space_guids) & Set.new(space_guids)).to_a
      end

      def visibility_filter?(message)
        [:space_guids, :organization_guids].any? { |filter| message.requested?(filter) }
      end

      def join_service_plans(dataset)
        dataset
      end

      def join_services(dataset)
        dataset
      end

      def join_service_instances(dataset)
        dataset = join_service_plans(dataset)
        join(dataset, :inner, :service_instances, service_plan_id: Sequel[:service_plans][:id])
      end

      def join_service_brokers(dataset)
        dataset = join_services(dataset)
        join(dataset, :inner, :service_brokers, id: Sequel[:services][:service_broker_id])
      end

      def join_broker_spaces(dataset)
        dataset = join_service_brokers(dataset)
        join(dataset, :left, Sequel[:spaces].as(:broker_spaces), id: Sequel[:service_brokers][:space_id])
      end

      def join_broker_orgs(dataset)
        dataset = join_broker_spaces(dataset)
        join(dataset, :left, Sequel[:organizations].as(:broker_orgs), id: Sequel[:broker_spaces][:organization_id])
      end

      def join_plan_orgs(dataset)
        dataset = join_service_plans(dataset)
        dataset = join(dataset, :left, :service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id])
        join(dataset, :left, Sequel[:organizations].as(:plan_orgs), id: Sequel[:service_plan_visibilities][:organization_id])
      end

      def join_plan_spaces(dataset)
        dataset = join_plan_orgs(dataset)
        join(dataset, :left, Sequel[:spaces].as(:plan_spaces), organization_id: Sequel[:plan_orgs][:id])
      end

      def join(dataset, type, table, on)
        dataset.opts[:join]&.each do |j|
          return dataset if j.table_expr == table
        end
        dataset.join_table(type, table, on)
      end
    end
  end
end
