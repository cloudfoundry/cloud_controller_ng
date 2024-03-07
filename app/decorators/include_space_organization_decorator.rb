module VCAP::CloudController
  class IncludeSpaceOrganizationDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w[org organization].include?(i) }
      end

      def decorate(hash, spaces)
        hash[:included] ||= {}
        organization_ids = spaces.map(&:organization_id).uniq
        organizations = Organization.where(id: organization_ids).order(:created_at, :guid).
                        eager(Presenters::V3::OrganizationPresenter.associated_resources).all

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
