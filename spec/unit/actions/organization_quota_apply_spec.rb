require 'spec_helper'
require 'actions/organization_quota_apply'
require 'messages/organization_quota_apply_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaApply do
    describe '#create' do
      subject { OrganizationQuotaApply.new }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:org_quota) { VCAP::CloudController::QuotaDefinition.make }
      let(:message) do
        VCAP::CloudController::OrganizationQuotaApplyMessage.new({
          data: [{ guid: org.guid }]
        })
      end

      context 'when applying quota to an org' do
        it 'associates given org with the quota' do
          expect {
            subject.apply(org_quota, message)
          }.to change { org_quota.organizations.count }.by 1

          expect(org_quota.organizations.count).to eq(1)
          expect(org_quota.organizations[0].guid).to eq(org.guid)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(org_quota).to receive(:add_organization).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.apply(org_quota, message)
          }.to raise_error(OrganizationQuotaApply::Error, 'blork is busted')
        end
      end

      context 'when the org guid is invalid' do
        let(:invalid_org_guid) { 'invalid_org_guid' }

        let(:message_with_invalid_org_guid) do
          VCAP::CloudController::OrganizationQuotaApplyMessage.new({
            data: [{ guid: invalid_org_guid }]
          })
        end

        it 'raises a human-friendly error' do
          expect {
            subject.apply(org_quota, message_with_invalid_org_guid)
          }.to raise_error(OrganizationQuotaApply::Error, "Organizations with guids [\"#{invalid_org_guid}\"] do not exist, or you do not have access to them.")
        end
      end
    end
  end
end
