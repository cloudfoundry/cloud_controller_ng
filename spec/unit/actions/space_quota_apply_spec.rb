require 'spec_helper'
require 'actions/space_quota_apply'
require 'messages/space_quota_apply_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaApply do
    let(:visible_space_guids) { [] }
    let(:all_spaces_visible) { false }

    describe '#apply' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

      subject { SpaceQuotaApply.new(user_audit_info) }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org) }
      let(:message) do
        VCAP::CloudController::SpaceQuotaApplyMessage.new({
                                                            data: [{ guid: space.guid }]
                                                          })
      end
      let(:visible_space_guids) { [] }

      context 'when applying quota to a space' do
        let(:visible_space_guids) { [space.guid] }

        it 'associates given space with the quota' do
          expect do
            subject.apply(space_quota, message, visible_space_guids:, all_spaces_visible:)
          end.to change { space_quota.spaces.count }.by 1

          expect(space_quota.spaces.count).to eq(1)
          expect(space_quota.spaces[0].guid).to eq(space.guid)
        end

        it 'creates an audit event' do
          subject.apply(space_quota, message, visible_space_guids:, all_spaces_visible:)

          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.space_quota.apply',
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
        let(:visible_space_guids) { [space.guid] }

        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(space_quota).to receive(:add_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect do
            subject.apply(space_quota, message, visible_space_guids:, all_spaces_visible:)
          end.to raise_error(SpaceQuotaApply::Error, 'blork is busted')
        end
      end

      context 'when the space does not exist' do
        let(:invalid_space_guid) { 'nonexistent-space-guid' }

        let(:message_with_invalid_space_guid) do
          VCAP::CloudController::SpaceQuotaApplyMessage.new({
                                                              data: [{ guid: invalid_space_guid }]
                                                            })
        end

        it 'raises a human-friendly error' do
          expect do
            subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids:, all_spaces_visible:)
          end.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end

      context 'when trying to set a log rate limit and there are apps with unlimited log rates' do
        let(:visible_space_guids) { [space.guid] }
        let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
        let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }
        let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, log_rate_limit: 2000) }

        it 'raises an error' do
          expect do
            subject.apply(space_quota, message, visible_space_guids:)
          end.to raise_error(SpaceQuotaApply::Error,
                             'Current usage exceeds new quota values. ' \
                             'The space(s) being assigned this quota contain apps running with an unlimited log rate limit.')
        end
      end

      context "when the space is outside the space quota's org" do
        let(:other_space) { VCAP::CloudController::Space.make }
        let(:invalid_space_guid) { other_space.guid }

        let(:message_with_invalid_space_guid) do
          VCAP::CloudController::SpaceQuotaApplyMessage.new({
                                                              data: [{ guid: invalid_space_guid }]
                                                            })
        end

        context 'when the space is readable by the user' do
          let(:visible_space_guids) { [invalid_space_guid] }

          it "displays an error indicating that the space is outside the quota's purview" do
            expect do
              subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids:, all_spaces_visible:)
            end.to raise_error(SpaceQuotaApply::Error, 'Space quotas cannot be applied outside of their owning organization.')
          end
        end

        context 'when the space is not readable by the user' do
          it 'displays an error indicating that the space may not exist' do
            expect do
              subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids:, all_spaces_visible:)
            end.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
          end
        end
      end

      context 'when applying quota to multiple spaces' do
        let(:space2) { VCAP::CloudController::Space.make(organization: org) }
        let(:visible_space_guids) { [space.guid, space2.guid] }
        let(:message) do
          VCAP::CloudController::SpaceQuotaApplyMessage.new({
                                                              data: [{ guid: space.guid }, { guid: space2.guid }]
                                                            })
        end

        it 'creates an audit event for each space' do
          subject.apply(space_quota, message, visible_space_guids:, all_spaces_visible:)

          expect(VCAP::CloudController::Event.count).to eq(2)
          events = VCAP::CloudController::Event.all

          space_event = events.find { |e| e.space_guid == space.guid }
          space2_event = events.find { |e| e.space_guid == space2.guid }

          expect(space_event.values).to include(
            type: 'audit.space_quota.apply',
            actee: space_quota.guid,
            space_guid: space.guid
          )
          expect(space_event.metadata).to eq({
                                               'space_guid' => space.guid,
                                               'space_name' => space.name
                                             })

          expect(space2_event.values).to include(
            type: 'audit.space_quota.apply',
            actee: space_quota.guid,
            space_guid: space2.guid
          )
          expect(space2_event.metadata).to eq({
                                                'space_guid' => space2.guid,
                                                'space_name' => space2.name
                                              })
        end
      end

      context 'when user is admin' do
        let(:all_spaces_visible) { true }

        it 'associates given space with the quota' do
          expect do
            subject.apply(space_quota, message, visible_space_guids:, all_spaces_visible:)
          end.to change { space_quota.spaces.count }.by 1

          expect(space_quota.spaces.count).to eq(1)
          expect(space_quota.spaces[0].guid).to eq(space.guid)
        end
      end
    end
  end
end
