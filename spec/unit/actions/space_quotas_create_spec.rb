require 'spec_helper'
require 'actions/space_quotas_create'
require 'messages/space_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasCreate do
    describe 'create' do
      subject(:space_quotas_create) { SpaceQuotasCreate.new }
      let(:org) { VCAP::CloudController::Organization.make(guid: 'some-org') }
      let(:message) do
        VCAP::CloudController::SpaceQuotasCreateMessage.new({
          name: 'my-name',
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            }
          }
        })
      end

      context 'when creating a space quota' do
        it 'creates a organization quota with the correct values' do
          space_quota = space_quotas_create.create(message, organization: org)

          expect(space_quota.name).to eq('my-name')

          expect(space_quota.organization).to eq(org)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::SpaceQuotaDefinition).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            space_quotas_create.create(message, organization: org)
          }.to raise_error(SpaceQuotasCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          before do
            space_quotas_create.create(message, organization: org)
          end

          it 'raises a human-friendly error' do
            expect {
              space_quotas_create.create(message, organization: org)
            }.to raise_error(SpaceQuotasCreate::Error, "Space Quota '#{message.name}' already exists.")
          end
        end
      end
    end
  end
end
