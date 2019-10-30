module VCAP::CloudController
  class ServiceOfferingsFetcher
    class << self
      def fetch_one(guid, org_guids: nil)
        return nil if org_guids == []
        return Service.find(guid: guid) unless org_guids

        guids = Service.dataset.
                join(:service_plans, service_id: :id).
                join(:service_plan_visibilities, service_plan_id: :id).
                join(:organizations, id: :organization_id).
                where(
                  Sequel[:organizations][:guid] => org_guids,
                  Sequel[:services][:guid] => guid
                ).
                select(Sequel[:services][:guid]).
                all.
                map(&:guid)

        Service.find(guid: guids.first)
      end
    end
  end
end
