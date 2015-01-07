require 'spec_helper'

describe UserSummaryPresenter do
  describe '#to_hash' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:managed_org) { VCAP::CloudController::Organization.make }
    let(:billing_managed_org) { VCAP::CloudController::Organization.make }
    let(:audited_org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:managed_space) { VCAP::CloudController::Space.make(organization: managed_org) }
    let(:audited_space) { VCAP::CloudController::Space.make(organization: audited_org) }
    let(:user) do
      u = make_developer_for_space(space)
      u.add_organization(managed_org)
      u.add_managed_organization(managed_org)
      managed_space.add_manager(u)

      u.add_organization(billing_managed_org)
      u.add_billing_managed_organization(billing_managed_org)

      u.add_organization(audited_org)
      u.add_audited_organization(audited_org)
      audited_space.add_auditor(u)

      u
    end

    subject { UserSummaryPresenter.new(user) }

    it 'creates a valid JSON' do
      expect(subject.to_hash).to eq({
        metadata: {
          guid: user.guid,
          created_at: user.created_at.iso8601,
          updated_at: nil,
        },
        entity: {
          organizations: [
            OrganizationPresenter.new(org).to_hash,
            OrganizationPresenter.new(managed_org).to_hash,
            OrganizationPresenter.new(billing_managed_org).to_hash,
            OrganizationPresenter.new(audited_org).to_hash
          ],
          managed_organizations: [OrganizationPresenter.new(managed_org).to_hash],
          billing_managed_organizations: [OrganizationPresenter.new(billing_managed_org).to_hash],
          audited_organizations: [OrganizationPresenter.new(audited_org).to_hash],
          spaces: [SpacePresenter.new(space).to_hash],
          managed_spaces: [SpacePresenter.new(managed_space).to_hash],
          audited_spaces: [SpacePresenter.new(audited_space).to_hash]
        }
      })
    end
  end
end
