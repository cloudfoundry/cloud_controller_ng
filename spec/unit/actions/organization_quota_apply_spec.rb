require 'spec_helper'
require 'actions/organization_quota_apply'
require 'messages/organization_quota_apply_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaApply do
    describe '#apply' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

      subject { OrganizationQuotaApply.new(user_audit_info) }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:org_quota) { VCAP::CloudController::QuotaDefinition.make }
      let(:message) do
        VCAP::CloudController::OrganizationQuotaApplyMessage.new({
                                                                   data: [{ guid: org.guid }]
                                                                 })
      end

      context 'when applying quota to an org' do
        it 'associates given org with the quota' do
          expect do
            subject.apply(org_quota, message)
          end.to change { org_quota.organizations.count }.by 1

          expect(org_quota.organizations.count).to eq(1)
          expect(org_quota.organizations[0].guid).to eq(org.guid)
        end

        it 'creates an audit event' do
          subject.apply(org_quota, message)

          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.organization_quota.apply',
            actee: org_quota.guid,
            actee_type: 'organization_quota',
            actee_name: org_quota.name,
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            space_guid: '',
            organization_guid: org.guid
          )
          expect(event.metadata).to eq({
                                         'organization_guid' => org.guid,
                                         'organization_name' => org.name
                                       })
          expect(event.timestamp).to be
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(org_quota).to receive(:add_organization).and_raise(Sequel::ValidationFailed.new(errors))

          expect do
            subject.apply(org_quota, message)
          end.to raise_error(OrganizationQuotaApply::Error, 'blork is busted')
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
          expect do
            subject.apply(org_quota, message_with_invalid_org_guid)
          end.to raise_error(OrganizationQuotaApply::Error, "Organizations with guids [\"#{invalid_org_guid}\"] do not exist")
        end
      end

      context 'when applying quota to multiple orgs' do
        let(:org2) { VCAP::CloudController::Organization.make }
        let(:message) do
          VCAP::CloudController::OrganizationQuotaApplyMessage.new({
                                                                     data: [{ guid: org.guid }, { guid: org2.guid }]
                                                                   })
        end

        it 'creates an audit event for each org' do
          subject.apply(org_quota, message)

          expect(VCAP::CloudController::Event.count).to eq(2)
          events = VCAP::CloudController::Event.all

          org_event = events.find { |e| e.organization_guid == org.guid }
          org2_event = events.find { |e| e.organization_guid == org2.guid }

          expect(org_event.values).to include(
            type: 'audit.organization_quota.apply',
            actee: org_quota.guid,
            organization_guid: org.guid
          )
          expect(org_event.metadata).to eq({
                                             'organization_guid' => org.guid,
                                             'organization_name' => org.name
                                           })

          expect(org2_event.values).to include(
            type: 'audit.organization_quota.apply',
            actee: org_quota.guid,
            organization_guid: org2.guid
          )
          expect(org2_event.metadata).to eq({
                                              'organization_guid' => org2.guid,
                                              'organization_name' => org2.name
                                            })
        end
      end

      context 'when trying to set a log rate limit and there are apps with unlimited log rates' do
        let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org) }
        let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
        let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }
        let(:org_quota) { VCAP::CloudController::QuotaDefinition.make(log_rate_limit: 2000) }

        it 'raises an error' do
          expect do
            subject.apply(org_quota, message)
          end.to raise_error(OrganizationQuotaApply::Error,
                             'Current usage exceeds new quota values. ' \
                             'The org(s) being assigned this quota contain apps running with an unlimited log rate limit.')
        end
      end
    end
  end
end
