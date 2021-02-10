module VCAP::CloudController
  class IncludeSpaceOrganizationDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(org organization).include?(i) }
      end

      def decorate(hash, spaces)
        hash[:included] ||= {}
        organization_guids = spaces.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).order(:created_at).
                        eager(Presenters::V3::OrganizationPresenter.associated_resources).all

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
