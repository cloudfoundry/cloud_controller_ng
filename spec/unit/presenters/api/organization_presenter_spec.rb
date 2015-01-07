require 'spec_helper'

describe OrganizationPresenter do
  describe '#to_hash' do
    let(:org) { VCAP::CloudController::Organization.make }
    before do
      VCAP::CloudController::Space.make(organization: org)
      user = VCAP::CloudController::User.make
      user.add_organization org
      user.add_managed_organization org
    end
    subject { OrganizationPresenter.new(org) }

    it 'creates a valid JSON' do
      expect(subject.to_hash).to eq({
        metadata: {
          guid: org.guid,
          created_at: org.created_at.iso8601,
          updated_at: nil,
        },
        entity: {
          name: org.name,
          billing_enabled: org.billing_enabled,
          status: org.status,
          spaces: org.spaces.map { |space| SpacePresenter.new(space).to_hash },
          quota_definition: QuotaDefinitionPresenter.new(org.quota_definition).to_hash,
          managers: org.managers.map { |manager| UserPresenter.new(manager).to_hash }
        }
      })
    end
  end
end
