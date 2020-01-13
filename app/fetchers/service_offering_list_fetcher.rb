module VCAP::CloudController
  class ServiceOfferingListFetcher
    def fetch(message)
      filter(message, Service.dataset)
    end

    def fetch_public(message)
      dataset = Service.dataset.
                join(:service_plans, service_id: Sequel[:services][:id]).
                where { Sequel[:service_plans][:public] =~ true }.
                group(Sequel[:services][:id]).
                select_all(:services)

      filter(message, dataset)
    end

    def fetch_visible(message, org_guids, space_guids)
      dataset = Service.dataset.
                join(:service_plans, service_id: Sequel[:services][:id]).
                join(:service_brokers, id: Sequel[:services][:service_broker_id]).
                left_join(:spaces, id: Sequel[:service_brokers][:space_id]).
                left_join(:service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id]).
                left_join(:organizations, id: Sequel[:service_plan_visibilities][:organization_id]).
                where do
        (Sequel[:organizations][:guid] =~ org_guids) |
        (Sequel[:service_plans][:public] =~ true) |
        (Sequel[:spaces][:guid] =~ space_guids)
      end.
                group(Sequel[:services][:id]).
                select_all(:services)

      filter(message, dataset)
    end

    def filter(message, dataset)
      if message.requested?(:available)
        dataset = dataset.where(Sequel[:services][:active] =~ string_to_boolean(message.available))
      end

      dataset
    end

    def string_to_boolean(value)
      value == 'true'
    end
  end
end
