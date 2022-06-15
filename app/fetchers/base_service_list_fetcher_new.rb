require 'set'
require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class BaseServiceListFetcherNew < BaseListFetcher
    class << self
      private

      def select_public_service_plans(dataset, omniscient: false)
        unless omniscient
          dataset = join_service_plans(dataset)
          dataset = dataset.where { Sequel[:service_plans][:public] =~ true }
        end

        dataset
      end

      def select_service_plans(message, dataset , omniscient: false, readable_spaces_query: nil, readable_orgs_query: nil)
        if readable_orgs_query
          dataset = join_service_plans(dataset)
          dataset = join_plan_org_visibilities(dataset)
          dataset = dataset.where { (Sequel[:service_plan_visibilities][:organization_id] =~ readable_orgs_query.select(:id)) }
        end

        if message.requested?(:space_guids)
          readable_space_guids = readable_spaces_query ? readable_spaces_query.select(:guid).all.map(&:guid) : []
          space_guids = authorized_space_guids(
            space_guids: message.space_guids,
            readable_space_guids: readable_space_guids,
            omniscient: omniscient,
            )
          dataset = join_plan_spaces(dataset)
          dataset = dataset.where { Sequel[:plan_spaces][:guid] =~ space_guids }
        end

        if message.requested?(:organization_guids)
          dataset = join_plan_orgs(dataset)
          dataset = dataset.where { Sequel[:plan_orgs][:guid] =~ message.organization_guids }
        end

        dataset
      end

      def select_service_plans_by_brokers(message, dataset , omniscient: false, readable_spaces_query: nil, readable_orgs_query: nil)

        if readable_orgs_query
          dataset = join_service_brokers(dataset)
          readable_space_ids_query = readable_spaces_query ? readable_spaces_query.select(:id) : nil
          dataset = dataset.where { Sequel[:service_brokers][:space_id] =~ readable_space_ids_query }
        end

        if message.requested?(:space_guids)
          readable_space_guids = readable_spaces_query ? readable_spaces_query.select(:guid).all.map(&:guid) : []
          space_guids = authorized_space_guids(
            space_guids: message.space_guids,
            readable_space_guids: readable_space_guids,
            omniscient: omniscient,
            )
          dataset = join_broker_spaces(dataset)
          dataset = dataset.where { Sequel[:broker_spaces][:guid] =~ space_guids }
        end

        if message.requested?(:organization_guids)
          dataset = join_broker_orgs(dataset)
          dataset = dataset.where { Sequel[:broker_orgs][:guid] =~ message.organization_guids }
        end

        dataset
      end

      def union(public_dataset, service_plan_dataset, service_broker_dataset)
        dataset = public_dataset.union(service_plan_dataset, :all=>true, :from_self=>false)
        dataset.union(service_broker_dataset, :all=>true, :from_self=>false).as(dataset.model.table_name)
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
        join(dataset, :inner, Sequel[:spaces].as(:broker_spaces), id: Sequel[:service_brokers][:space_id])
      end

      def join_broker_orgs(dataset)
        dataset = join_broker_spaces(dataset)
        join(dataset, :inner, Sequel[:organizations].as(:broker_orgs), id: Sequel[:broker_spaces][:organization_id])
      end

      def join_plan_org_visibilities(dataset)
        dataset = join_service_plans(dataset)
        join(dataset, :inner, :service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id])
      end

      def join_plan_orgs(dataset)
        dataset = join_plan_org_visibilities(dataset)
        join(dataset, :inner, Sequel[:organizations].as(:plan_orgs), id: Sequel[:service_plan_visibilities][:organization_id])
      end

      def join_plan_spaces(dataset)
        dataset = join_plan_orgs(dataset)
        join(dataset, :inner, Sequel[:spaces].as(:plan_spaces), organization_id: Sequel[:plan_orgs][:id])
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
