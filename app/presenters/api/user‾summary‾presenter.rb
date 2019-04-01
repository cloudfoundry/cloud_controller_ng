require_relative 'api_presenter'
require_relative 'organization_presenter'

class UserSummaryPresenter < ApiPresenter
  def entity_hash
    {
      organizations: present_orgs(@object.organizations),
      managed_organizations: present_orgs(@object.managed_organizations),
      billing_managed_organizations: present_orgs(@object.billing_managed_organizations),
      audited_organizations: present_orgs(@object.audited_organizations),
      spaces: present_spaces(@object.spaces),
      managed_spaces: present_spaces(@object.managed_spaces),
      audited_spaces: present_spaces(@object.audited_spaces)
    }
  end

  private

  def present_orgs(orgs)
    orgs.map { |org| OrganizationPresenter.new(org).to_hash }
  end

  def present_spaces(spaces)
    spaces.map { |space| SpacePresenter.new(space).to_hash }
  end
end
