require 'spec_helper'
require 'actions/security_group_create'
require 'models/runtime/security_group'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreate do
    describe 'create' do
      subject { SecurityGroupCreate.create(message) }

      context 'when creating a space' do
        context 'with default values' do
          let(:message) { VCAP::CloudController::SecurityGroupCreateMessage.new(
            {
              name: 'secure-group'
            })
          }

          it 'creates a space' do
            created_group = nil
            expect {
              created_group = subject
            }.to change { SecurityGroup.count }.by(1)

            expect(created_group.guid).to be_a_guid
            expect(created_group.name).to eq 'secure-group'
            expect(created_group.running_default).to be_nil
            expect(created_group.staging_default).to be_nil
            expect(created_group.spaces.count).to eq(0)
          end
        end

        context 'with provided values' do
          let(:space1) { VCAP::CloudController::Space.make }
          let(:space2) { VCAP::CloudController::Space.make }
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

          it 'creates a space' do
            created_group = nil
            expect {
              created_group = subject
            }.to change { SecurityGroup.count }.by(1)

            expect(created_group.guid).to be_a_guid
            expect(created_group.name).to eq 'secure-group'
            expect(created_group.running_default).to be true
            expect(created_group.staging_default).to be false
            expect(created_group.staging_spaces).to contain_exactly space1
            expect(created_group.spaces).to contain_exactly space2
          end
        end
      end
    end
  end
end
