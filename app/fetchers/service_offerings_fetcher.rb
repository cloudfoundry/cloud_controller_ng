module VCAP::CloudController
  class ServiceOfferingsFetcher
    class << self
      def fetch_one(guid, org_guids: nil)
        return Service.find(guid: guid) unless org_guids

        guids = Service.dataset.
                join(:service_plans, service_id: :id).
                left_join(:service_plan_visibilities, service_plan_id: :id).
                left_join(:organizations, id: :organization_id).
                where do
                  (Sequel[:services][:guid] =~ guid) &
                    ((Sequel[:service_plans][:public] =~ true) | (Sequel[:organizations][:guid] =~ org_guids))
                end.
                select(Sequel[:services][:guid]).
                all.
                map(&:guid)

        Service.find(guid: guids.first)
      end

      def fetch_one_anonymously(guid)
        guids = Service.dataset.
                join(:service_plans, service_id: :id).
                where { (Sequel[:services][:guid] =~ guid) & (Sequel[:service_plans][:public] =~ true) }.
                select(Sequel[:services][:guid]).
                all.
                map(&:guid)

        Service.find(guid: guids.first)
      end
    end
  end
end
