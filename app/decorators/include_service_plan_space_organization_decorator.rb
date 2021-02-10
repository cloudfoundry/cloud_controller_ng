module VCAP::CloudController
  class IncludeServicePlanSpaceOrganizationDecorator
    class << self
      def match?(include)
        include&.include?('space.organization')
      end

      def decorate(hash, service_plans)
        hash[:included] ||= {}
        spaces = Space.where(id: service_plans.map { |p| p.service.service_broker.space_id }.compact.uniq).
                 order(:created_at).eager(Presenters::V3::SpacePresenter.associated_resources).all
        orgs = Organization.where(id: spaces.map(&:organization_id).uniq).order(:created_at).
               eager(Presenters::V3::OrganizationPresenter.associated_resources).all

        hash[:included][:spaces] = spaces.sort_by(&:created_at).map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash[:included][:organizations] = orgs.sort_by(&:created_at).map { |org| Presenters::V3::OrganizationPresenter.new(org).to_hash }
        hash
      end
    end
  end
end
