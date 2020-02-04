module VCAP::CloudController
  class ServicePlanListFetcher
    def fetch(omniscient: false, space_guids: [], org_guids: [])
      dataset = ServicePlan.dataset

      unless omniscient
        dataset = dataset.where { Sequel[:service_plans][:public] =~ true }

        if space_guids.any?
          dataset_for_spaces = ServicePlan.dataset.
                               join(:services, id: Sequel[:service_plans][:service_id]).
                               join(:service_brokers, id: Sequel[:services][:service_broker_id]).
                               join(:spaces, id: Sequel[:service_brokers][:space_id]).
                               where { Sequel[:spaces][:guid] =~ space_guids }.
                               select_all(:service_plans)

          dataset = dataset.union(dataset_for_spaces, alias: :service_plans)
        end

        if org_guids.any?
          dataset_for_orgs = ServicePlan.dataset.
                             join(:service_plan_visibilities, service_plan_id: Sequel[:service_plans][:id]).
                             join(:organizations, id: Sequel[:service_plan_visibilities][:organization_id]).
                             where { Sequel[:organizations][:guid] =~ org_guids }.
                             select_all(:service_plans)

          dataset = dataset.union(dataset_for_orgs, alias: :service_plans)
        end
      end

      dataset.distinct
    end
  end
end
