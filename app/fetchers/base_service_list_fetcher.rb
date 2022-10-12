require 'set'
require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class BaseServiceListFetcher < BaseListFetcher
    class << self
      private

      def fetch(klass, message, omniscient: false, readable_orgs_query: nil, readable_spaces_query: nil, eager_loaded_associations: [])
        # The base dataset for the given model; other tables might be joined later on for filtering,
        # but we are only interested in the columns from the base table.
        dataset = klass.dataset.select_all(klass.table_name)

        # The simple filters (i.e. resulting in INNER JOINs and ANDed WHERE conditions) are applied first.
        dataset = filter(message, dataset, klass)

        # Filter by permissions granted on org level for plans.
        plan_dataset = readable_by_plan_org(dataset, readable_orgs_query)

        # Filter by permissions granted on space level for brokers.
        broker_dataset = readable_by_broker_space(dataset, readable_spaces_query)

        # Apply additional filtering by org / space guids (if requested).
        if message.requested?(:organization_guids)
          plan_dataset, broker_dataset = filter_by_org_guid(
            message.organization_guids,
            plan_dataset,
            broker_dataset,
            omniscient,
            readable_orgs_query,
            readable_spaces_query,
            dataset)
        end

        if message.requested?(:space_guids)
          plan_dataset, broker_dataset = filter_by_space_guid(
            message.space_guids,
            plan_dataset,
            broker_dataset,
            omniscient,
            readable_orgs_query,
            readable_spaces_query,
            dataset)
        end

        # Add filter for public plans. This is needed for non-admin users or in addition to the other datasets (i.e. an admin
        # that filters for a specific org / space guid also gets the public plans).
        if !omniscient || (!plan_dataset.nil? || !broker_dataset.nil?)
          public_dataset = publicly_readable(dataset)
        end

        # For performance reasons, the three sub-queries are processed individually and UNIONed together.
        datasets = [plan_dataset, broker_dataset, public_dataset].compact
        dataset = if datasets.empty?
                    # No sub-query required (i.e. admin user without filters for org / space guids)
                    dataset
                  elsif datasets.length == 1
                    # A single sub-query does not need to be UNIONed (i.e. unauthenticated user retrieving public plans)
                    datasets[0]
                  else
                    datasets.reduce do |ds1, ds2|
                      ds1.union(ds2, all: true, from_self: false)
                    end.from_self(alias: klass.table_name)
                  end

        # Select DISTINCT entries and eager load associations.
        dataset.distinct.eager(eager_loaded_associations)
      end

      def readable_by_plan_org(dataset, readable_orgs_query)
        unless readable_orgs_query.nil?
          plan_dataset = dataset.clone
          plan_dataset = join_plan_org_visibilities(plan_dataset)
          plan_dataset.where { Sequel[:service_plan_visibilities][:organization_id] =~ readable_orgs_query.select(:id) }
        end
      end

      def readable_by_broker_space(dataset, readable_spaces_query)
        unless readable_spaces_query.nil?
          broker_dataset = dataset.clone
          broker_dataset = join_service_brokers(broker_dataset)
          broker_dataset.where { Sequel[:service_brokers][:space_id] =~ readable_spaces_query.select(:id) }
        end
      end

      def filter_by_org_guid(org_guids, plan_dataset, broker_dataset, omniscient, readable_orgs_query, readable_spaces_query, dataset)
        authorized_org_guids = if !omniscient && !readable_orgs_query.nil?
                                 readable_orgs_query.where(guid: org_guids).select_map(:guid)
                               else
                                 org_guids
                               end

        if omniscient || !readable_orgs_query.nil?
          plan_dataset = dataset.clone if plan_dataset.nil?
          plan_dataset = join_plan_orgs(plan_dataset)
          plan_dataset = plan_dataset.where { Sequel[:plan_orgs][:guid] =~ authorized_org_guids }
        end

        if omniscient || !readable_spaces_query.nil?
          broker_dataset = dataset.clone if broker_dataset.nil?
          broker_dataset = join_broker_orgs(broker_dataset)
          broker_dataset = broker_dataset.where { Sequel[:broker_orgs][:guid] =~ authorized_org_guids }
        end

        [plan_dataset, broker_dataset]
      end

      def filter_by_space_guid(space_guids, plan_dataset, broker_dataset, omniscient, readable_orgs_query, readable_spaces_query, dataset)
        authorized_space_guids = if !omniscient && !readable_spaces_query.nil?
                                   readable_spaces_query.where(guid: space_guids).select_map(:guid)
                                 else
                                   space_guids
                                 end

        if omniscient || !readable_orgs_query.nil?
          plan_dataset = dataset.clone if plan_dataset.nil?
          plan_dataset = join_plan_spaces(plan_dataset)
          plan_dataset = plan_dataset.where { Sequel[:plan_spaces][:guid] =~ authorized_space_guids }
        end

        if omniscient || !readable_spaces_query.nil?
          broker_dataset = dataset.clone if broker_dataset.nil?
          broker_dataset = join_broker_spaces(broker_dataset)
          broker_dataset = broker_dataset.where { Sequel[:broker_spaces][:guid] =~ authorized_space_guids }
        end

        [plan_dataset, broker_dataset]
      end

      def publicly_readable(dataset)
        public_dataset = dataset.clone
        public_dataset = join_service_plans(public_dataset)
        public_dataset.where { Sequel[:service_plans][:public] =~ true }
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

      def join_service_plans(dataset)
        dataset
      end

      def join_services(dataset)
        dataset
      end

      def join_plan_org_visibilities(dataset)
        dataset = join_service_plans(dataset)
        join(dataset, :inner, :service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id])
      end

      def join_service_brokers(dataset)
        dataset = join_services(dataset)
        join(dataset, :inner, :service_brokers, id: Sequel[:services][:service_broker_id])
      end

      def join_plan_orgs(dataset)
        dataset = join_plan_org_visibilities(dataset)
        join(dataset, :inner, Sequel[:organizations].as(:plan_orgs), id: Sequel[:service_plan_visibilities][:organization_id])
      end

      def join_broker_spaces(dataset)
        dataset = join_service_brokers(dataset)
        join(dataset, :inner, Sequel[:spaces].as(:broker_spaces), id: Sequel[:service_brokers][:space_id])
      end

      def join_broker_orgs(dataset)
        dataset = join_broker_spaces(dataset)
        join(dataset, :inner, Sequel[:organizations].as(:broker_orgs), id: Sequel[:broker_spaces][:organization_id])
      end

      def join_plan_spaces(dataset)
        dataset = join_plan_orgs(dataset)
        join(dataset, :inner, Sequel[:spaces].as(:plan_spaces), organization_id: Sequel[:plan_orgs][:id])
      end

      def join_service_instances(dataset)
        dataset = join_service_plans(dataset)
        join(dataset, :inner, :service_instances, service_plan_id: Sequel[:service_plans][:id])
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
