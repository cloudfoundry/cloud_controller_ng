require 'spec_helper'
require 'actions/space_quota_apply'
require 'messages/space_quota_apply_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaApply do
    describe '#create' do
      subject { SpaceQuotaApply.new }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org) }
      let(:message) do
        VCAP::CloudController::SpaceQuotaApplyMessage.new({
          data: [{ guid: space.guid }]
        })
      end

      context 'when applying quota to a space' do
        it 'associates given space with the quota' do
          expect {
            subject.apply(space_quota, message)
          }.to change { space_quota.spaces.count }.by 1

          expect(space_quota.spaces.count).to eq(1)
          expect(space_quota.spaces[0].guid).to eq(space.guid)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(space_quota).to receive(:add_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.apply(space_quota, message)
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
            subject.apply(space_quota, message_with_invalid_space_guid)
          }.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end

      context 'when the space does not belong in the same organization as the space quota' do
        let(:other_space) { VCAP::CloudController::Space.make }
        let(:invalid_space_guid) { other_space.guid }

        let(:message_with_invalid_space_guid) do
          VCAP::CloudController::SpaceQuotaApplyMessage.new({
            data: [{ guid: invalid_space_guid }]
          })
        end

        it 'raises a human-friendly error' do
          expect {
            subject.apply(space_quota, message_with_invalid_space_guid)
          }.to raise_error(SpaceQuotaApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end
    end
  end
end
