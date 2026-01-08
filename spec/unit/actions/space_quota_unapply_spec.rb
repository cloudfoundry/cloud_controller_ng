require 'spec_helper'
require 'actions/space_quota_unapply'

module VCAP::CloudController
  RSpec.describe SpaceQuotaUnapply do
    describe '#unapply' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

      subject { SpaceQuotaUnapply.new(user_audit_info) }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org) }
      let!(:space) { VCAP::CloudController::Space.make(organization: org, space_quota_definition: space_quota) }

      context 'when removing a quota from a space' do
        it 'disassociates the given space from the quota' do
          expect(space_quota.spaces[0].guid).to eq(space.guid)
          expect do
            subject.unapply(space_quota, space)
          end.to change { space_quota.spaces.count }.by(-1)

          expect(space_quota.spaces.count).to eq(0)
        end

        it 'creates an audit event' do
          subject.unapply(space_quota, space)

          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.space_quota.remove',
            actee: space_quota.guid,
            actee_type: 'space_quota',
            actee_name: space_quota.name,
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            space_guid: space.guid,
            organization_guid: space_quota.organization.guid
          )
          expect(event.metadata).to eq({
                                         'space_guid' => space.guid,
                                         'space_name' => space.name
                                       })
          expect(event.timestamp).to be
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(space_quota).to receive(:remove_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect do
            subject.unapply(space_quota, space)
          end.to raise_error(SpaceQuotaUnapply::Error, 'blork is busted')
        end
      end
    end
  end
end
