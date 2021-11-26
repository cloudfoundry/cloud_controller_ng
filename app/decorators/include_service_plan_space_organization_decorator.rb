module VCAP::CloudController
  class IncludeServicePlanSpaceOrganizationDecorator
    class << self
      def associated_fields
        {
          service: {
            service_broker: {
              space: Presenters::V3::SpacePresenter.all_fields + [{
                organization: Presenters::V3::OrganizationPresenter.all_fields
              }],
            }
          }
        }
      end

      def match?(include)
        include&.include?('space.organization')
      end

      def decorate(hash, service_plans)
        hash[:included] ||= {}
        spaces = service_plans.map { |p| p.service.service_broker.space }.compact.uniq
        orgs = spaces.map(&:organization).uniq
        hash[:included][:spaces] = spaces.sort_by(&:created_at).map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash[:included][:organizations] = orgs.sort_by(&:created_at).map { |org| Presenters::V3::OrganizationPresenter.new(org).to_hash }
        hash
      end
    end
  end
end
