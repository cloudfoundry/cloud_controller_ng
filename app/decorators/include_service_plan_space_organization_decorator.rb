module VCAP::CloudController
  class IncludeServicePlanSpaceOrganizationDecorator
    class << self
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
