require 'spec_helper'
require 'actions/security_group_create'
require 'messages/security_group_create_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreate do
    describe 'create' do
      subject { SecurityGroupCreate }

      context 'when creating a security group' do
        let(:group) { VCAP::CloudController::SecurityGroup.make }

        let(:message) do
          VCAP::CloudController::SecurityGroupCreateMessage.new({
            name: 'my-name'
          })
        end

        it 'creates a security group with the correct values' do
          group = subject.create(message)

          expect(group.name).to eq('my-name')
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::SecurityGroup).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::SecurityGroupCreateMessage.new(name: 'foobar')
          expect {
            subject.create(message)
          }.to raise_error(SecurityGroupCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }
          let(:message) { VCAP::CloudController::SecurityGroupCreateMessage.new(name: name) }

          before do
            subject.create(message)
          end

          it 'raises a human-friendly error' do
            expect {
              subject.create(message)
            }.to raise_error(SecurityGroupCreate::Error, "Security group with name '#{name}' already exists.")
          end
        end
      end
    end
  end
end
