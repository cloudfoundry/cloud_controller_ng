require 'spec_helper'
require 'actions/security_group_apply'
require 'messages/security_group_apply_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupApply do
    describe '#apply_running' do
      subject { SecurityGroupApply }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }
      let(:message) do
        VCAP::CloudController::SecurityGroupApplyMessage.new({
                                                               data: [{ guid: space.guid }]
                                                             })
      end
      let(:readable_space_guids) { [space.guid] }

      context 'when applying quota to a space' do
        it 'associates given space with the quota' do
          expect {
            subject.apply_running(security_group, message, readable_space_guids)
          }.to change { security_group.spaces.count }.by 1

          expect(security_group.spaces.count).to eq(1)
          expect(security_group.spaces[0].guid).to eq(space.guid)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(security_group).to receive(:add_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.apply_running(security_group, message, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, 'blork is busted')
        end
      end

      context 'when the space does not exist' do
        let(:invalid_space_guid) { 'nonexistent-space-guid' }

        let(:message_with_invalid_space_guid) do
          VCAP::CloudController::SecurityGroupApplyMessage.new({
                                                                 data: [{ guid: invalid_space_guid }]
                                                               })
        end

        it 'raises a human-friendly error' do
          expect {
            subject.apply_running(security_group, message_with_invalid_space_guid, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end

      context 'when the space is not readable by the user' do
        let(:readable_space_guids) { [] }

        it 'associates given space with the quota' do
          expect {
            subject.apply_running(security_group, message, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, "Spaces with guids [\"#{space.guid}\"] do not exist, or you do not have access to them.")

          expect(security_group.spaces.count).to eq(0)
        end
      end
    end

    describe '#apply_staging' do
      subject { SecurityGroupApply }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }
      let(:message) do
        VCAP::CloudController::SecurityGroupApplyMessage.new({
                                                               data: [{ guid: space.guid }]
                                                             })
      end
      let(:readable_space_guids) { [space.guid] }

      context 'when applying quota to a space' do
        it 'associates given space with the quota' do
          expect {
            subject.apply_staging(security_group, message, readable_space_guids)
          }.to change { security_group.staging_spaces.count }.by 1

          expect(security_group.staging_spaces.count).to eq(1)
          expect(security_group.staging_spaces[0].guid).to eq(space.guid)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(security_group).to receive(:add_staging_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.apply_staging(security_group, message, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, 'blork is busted')
        end
      end

      context 'when the space does not exist' do
        let(:invalid_space_guid) { 'nonexistent-space-guid' }

        let(:message_with_invalid_space_guid) do
          VCAP::CloudController::SecurityGroupApplyMessage.new({
                                                                 data: [{ guid: invalid_space_guid }]
                                                               })
        end

        it 'raises a human-friendly error' do
          expect {
            subject.apply_staging(security_group, message_with_invalid_space_guid, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist, or you do not have access to them.")
        end
      end

      context 'when the space is not readable by the user' do
        let(:readable_space_guids) { [] }

        it 'associates given space with the quota' do
          expect {
            subject.apply_staging(security_group, message, readable_space_guids)
          }.to raise_error(SecurityGroupApply::Error, "Spaces with guids [\"#{space.guid}\"] do not exist, or you do not have access to them.")

          expect(security_group.staging_spaces.count).to eq(0)
        end
      end
    end
  end
end
