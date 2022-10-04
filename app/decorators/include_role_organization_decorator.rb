module VCAP::CloudController
  class IncludeRoleOrganizationDecorator
    class << self
      def match?(include_params)
        # roles may be associated with an org without being associated with a space
        # this is why this is not `space.organization`
        include_params&.include?('organization')
      end

      def decorate(hash, roles)
        hash[:included] ||= {}
        organization_guids = roles.map { |role| role.organization_guid unless role.for_space? }.uniq
        organizations = Organization.where(guid: organization_guids).
                        order(:created_at).eager(Presenters::V3::OrganizationPresenter.associated_resources).all

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
