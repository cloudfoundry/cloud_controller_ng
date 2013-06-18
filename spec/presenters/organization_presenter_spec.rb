require 'spec_helper'

describe OrganizationPresenter do
  describe "#to_hash" do
    let(:org) { VCAP::CloudController::Models::Organization.make }
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
          quota_definition: QuotaDefinitionPresenter.new(org.quota_definition).to_hash
        }
      })
    end
  end
end
