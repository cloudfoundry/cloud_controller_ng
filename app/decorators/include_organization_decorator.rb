module VCAP::CloudController
  class IncludeOrganizationDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(org space.organization).include?(i) }
      end

      def decorate(hash, resources)
        hash[:included] ||= {}
        organization_guids = resources.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).
                        order(:created_at).eager(Presenters::V3::OrganizationPresenter.associated_resources).all

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
