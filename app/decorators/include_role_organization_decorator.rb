module VCAP::CloudController
  class IncludeRoleOrganizationDecorator
    class << self
      def match?(include_params)
        include_params&.include?('organization')
      end

      def decorate(hash, roles)
        hash[:included] ||= {}
        organization_guids = roles.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).order(:created_at)

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
