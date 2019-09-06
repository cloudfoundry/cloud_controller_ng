module VCAP::CloudController
  class IncludeAppOrganizationDecorator
    class << self
      def match?(include)
        include&.include?('org')
      end

      def decorate(hash, apps)
        hash[:included] ||= {}
        organization_guids = apps.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).order(:created_at)

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
