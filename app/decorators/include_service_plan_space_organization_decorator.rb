module VCAP::CloudController
  class IncludeServicePlanSpaceOrganizationDecorator
    class << self
      def match?(include)
        include&.include?('space.organization')
      end

      def decorate(hash, service_plans)
        hash[:included] ||= {}
        space_ids = service_plans.map { |p| p.service.service_broker.space_id }.compact.uniq
        unless space_ids.empty?
          spaces = Space.where(id: space_ids).order(:created_at, :guid).
                   eager(Presenters::V3::SpacePresenter.associated_resources).all
          orgs = Organization.where(id: spaces.map(&:organization_id).uniq).order(:created_at, :guid).
                 eager(Presenters::V3::OrganizationPresenter.associated_resources).all
        end

        hash[:included][:spaces] = spaces&.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash } || []
        hash[:included][:organizations] = orgs&.map { |org| Presenters::V3::OrganizationPresenter.new(org).to_hash } || []
        hash
      end
    end
  end
end
