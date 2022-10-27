require 'spec_helper'
require 'actions/space_quota_apply'
require 'messages/space_quota_apply_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaApply do
    let(:visible_space_guids) { [] }
    let(:all_spaces_visible) { false }

    describe '#apply' do
      subject { SpaceQuotaApply.new }

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
          expect {
            subject.apply(space_quota, message, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
          }.to change { space_quota.spaces.count }.by 1

          expect(space_quota.spaces.count).to eq(1)
          expect(space_quota.spaces[0].guid).to eq(space.guid)
        end
      end

      context 'when a model validation fails' do
        let(:visible_space_guids) { [space.guid] }

        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(space_quota).to receive(:add_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.apply(space_quota, message, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
          }.to raise_error(SpaceQuotaApply::Error, 'blork is busted')
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
          expect {
            subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
          }.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end

      context 'when trying to set a log rate limit and there are apps with unlimited log rates' do
        let(:visible_space_guids) { [space.guid] }
        let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
        let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }
        let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, log_rate_limit: 2000) }

        it 'raises an error' do
          expect {
            subject.apply(space_quota, message, visible_space_guids: visible_space_guids)
          }.to raise_error(SpaceQuotaApply::Error,
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
            expect {
              subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
            }.to raise_error(SpaceQuotaApply::Error, 'Space quotas cannot be applied outside of their owning organization.')
          end
        end

        context 'when the space is not readable by the user' do
          it 'displays an error indicating that the space may not exist' do
            expect {
              subject.apply(space_quota, message_with_invalid_space_guid, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
            }.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
          end
        end
      end

      context 'when user is admin' do
        let(:all_spaces_visible) { true }

        it 'associates given space with the quota' do
          expect {
            subject.apply(space_quota, message, visible_space_guids: visible_space_guids, all_spaces_visible: all_spaces_visible)
          }.to change { space_quota.spaces.count }.by 1

          expect(space_quota.spaces.count).to eq(1)
          expect(space_quota.spaces[0].guid).to eq(space.guid)
        end
      end
    end
  end
end
