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
        organization_ids = roles.reject(&:for_space?).map(&:organization_id).uniq
        unless organization_ids.empty?
          organizations = Organization.where(id: organization_ids).order(:created_at, :guid).
                          eager(Presenters::V3::OrganizationPresenter.associated_resources).all
        end

        hash[:included][:organizations] = organizations&.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash } || []
        hash
      end
    end
  end
end
