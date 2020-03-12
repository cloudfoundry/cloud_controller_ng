require 'spec_helper'
require 'actions/security_group_update'
require 'messages/security_group_update_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupUpdate do
    describe 'update' do
      let(:update_message) { VCAP::CloudController::SecurityGroupUpdateMessage.new(name: name) }
      let(:name) { 'my-security-group' }

      let!(:security_group) do
        VCAP::CloudController::SecurityGroup.make(
          name: 'original-name',
          rules: [{ 'protocol' => 'udp', 'ports' => '8080', 'destination' => '198.41.191.47/1' }],
          running_default: false,
          staging_default: true,
        )
      end

      context 'when updating a security group' do
        let(:update_message) do
          VCAP::CloudController::SecurityGroupUpdateMessage.new(
            name: name,
            globally_enabled: {
              running: true,
              staging: false,
            },
            rules: [],
          )
        end

        it 'successfully updates the security group with the new parameters' do
          updated_security_group = SecurityGroupUpdate.update(security_group, update_message)

          expect(updated_security_group.name).to eq('my-security-group')
          expect(updated_security_group.rules).to eq([])
          expect(updated_security_group.running_default).to be true
          expect(updated_security_group.staging_default).to be false
        end
      end

      context 'when partially updating a security group' do
        let(:update_message) do
          VCAP::CloudController::SecurityGroupUpdateMessage.new(
            globally_enabled: {
              running: true,
            },
            rules: [],
          )
        end

        it 'merges the globally_enabled properties and replaces the rules' do
          updated_security_group = SecurityGroupUpdate.update(security_group, update_message)

          expect(updated_security_group.rules).to eq([])
          expect(updated_security_group.running_default).to be true
          expect(updated_security_group.staging_default).to be true
        end

        it 'does not update fields that are not requested' do
          updated_security_group = SecurityGroupUpdate.update(security_group, update_message)

          expect(updated_security_group.name).to eq('original-name')
        end
      end

      context 'when a model validation fails' do
        before do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          allow(security_group).to receive(:save).
            and_raise(Sequel::ValidationFailed.new(errors))
        end

        it 'raises an error' do
          expect {
            SecurityGroupUpdate.update(security_group, update_message)
          }.to raise_error(SecurityGroupUpdate::Error, 'blork is busted')
        end
      end

      context 'when a uniqueness error occurs due to the requested name' do
        let!(:original) { VCAP::CloudController::SecurityGroup.make(name: name) }

        it 'raises a human-friendly error' do
          expect {
            SecurityGroupUpdate.update(security_group, update_message)
          }.to raise_error(SecurityGroupUpdate::Error, "Security group with name '#{name}' already exists.")
        end
      end
    end
  end
end
