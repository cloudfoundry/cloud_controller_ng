require_relative 'abstract_presenter'
require_relative 'organization_presenter'

class UserSummaryPresenter < AbstractPresenter
  def entity_hash
    {
      organizations: @object.organizations.map { |org| OrganizationPresenter.new(org).to_hash }
    }
  end
end
