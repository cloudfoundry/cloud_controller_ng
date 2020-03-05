require 'spec_helper'
require 'actions/security_group_create'
require 'models/runtime/security_group'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreate do
    describe 'create' do
      subject { SecurityGroupCreate }
      let(:space1) { VCAP::CloudController::Space.make }
      let(:space2) { VCAP::CloudController::Space.make }

      context 'when creating a security-group' do
        context 'with default values' do
          let(:message) { VCAP::CloudController::SecurityGroupCreateMessage.new(
            {
              name: 'secure-group'
            })
          }

          it 'creates a security-group' do
            created_group = nil
            expect {
              created_group = subject.create(message)
            }.to change { SecurityGroup.count }.by(1)

            expect(created_group.guid).to be_a_guid
            expect(created_group.name).to eq 'secure-group'
            expect(created_group.rules).to eq([])
            expect(created_group.running_default).to eq(false)
            expect(created_group.staging_default).to eq(false)
            expect(created_group.spaces.count).to eq(0)
          end
        end

        context 'with provided values' do
          let(:message) { VCAP::CloudController::SecurityGroupCreateMessage.new(
            {
              name: 'secure-group',
              globally_enabled: {
                running: true,
                staging: false
              },
              relationships: {
                staging_spaces: {
                  data: [
                    { guid: space1.guid }
                  ]
                },
                running_spaces: {
                  data: [
                    { guid: space2.guid }
                  ]
                }
              },
            })
          }

          it 'creates a security-group' do
            created_group = nil
            expect {
              created_group = subject.create(message)
            }.to change { SecurityGroup.count }.by(1)

            expect(created_group.guid).to be_a_guid
            expect(created_group.name).to eq 'secure-group'
            expect(created_group.running_default).to be true
            expect(created_group.staging_default).to be false
            expect(created_group.staging_spaces).to contain_exactly space1
            expect(created_group.spaces).to contain_exactly space2
          end
        end

        context 'with rules' do
          let(:group) { VCAP::CloudController::SecurityGroup.make }

          let(:first_group) do
            {
              protocol: 'tcp',
              destination: '10.10.10.0/24',
              ports: '443,80,8080'
            }
          end

          let(:second_group) do
            {
              protocol: 'icmp',
              destination: '10.11.10.0/24',
              type: 8,
              code: 0,
              description: 'Allow ping requests to private services'
            }
          end

          let(:message) do
            VCAP::CloudController::SecurityGroupCreateMessage.new({
              name: 'my-name',
              rules: [
                first_group,
                second_group
              ]
            })
          end

          it 'creates a security group with the correct values' do
            security_group = subject.create(message)

            expect(security_group.name).to eq('my-name')

            expect(security_group.rules).to contain_exactly(first_group, second_group)
          end
        end

        context 'when the space does not exist' do
          let(:invalid_space_guid) { 'invalid_space_guid' }
          let(:message) do
            VCAP::CloudController::SecurityGroupCreateMessage.new({
              name: 'my-name',
              relationships: {
                running_spaces: { data: [{ guid: space1.guid }, { guid: invalid_space_guid }] }
              }
            })
          end

          it 'raises a human-friendly error' do
            num_sec_groups = SecurityGroup.count
            expect {
              subject.create(message)
            }.to raise_error(subject::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist.")

            expect(SecurityGroup.count).to eq num_sec_groups
          end
        end

        context 'when a model validation fails' do
          let(:message) { VCAP::CloudController::SecurityGroupCreateMessage.new(name: 'foobar') }

          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::SecurityGroup).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))

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
end
