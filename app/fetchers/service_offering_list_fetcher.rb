module VCAP::CloudController
  class ServiceOfferingListFetcher
    def fetch_all
      Service.dataset
    end

    def fetch_public
      Service.dataset.
        join(:service_plans, service_id: Sequel[:services][:id]).
        where { Sequel[:service_plans][:public] =~ true }.
        group(Sequel[:services][:id]).
        select_all(:services)
    end

    def fetch(org_guids, space_guids)
      Service.dataset.
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
    end
  end
end
