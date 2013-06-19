require 'spec_helper'

describe OrganizationPresenter do
  describe "#to_hash" do
    let(:org) { VCAP::CloudController::Models::Organization.make }
    before do
      VCAP::CloudController::Models::Space.make(organization: org)
      user = VCAP::CloudController::Models::User.make
      user.add_managed_organization org
    end
    subject { OrganizationPresenter.new(org) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        metadata: {
          guid: org.guid,
          created_at: org.created_at.to_s,
          updated_at: org.updated_at.to_s
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
