module VCAP::CloudController
  class IncludeAppOrganizationDecorator
    class << self
      def decorate(hash, apps)
        hash[:included] ||= {}
        organization_guids = apps.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids)

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
