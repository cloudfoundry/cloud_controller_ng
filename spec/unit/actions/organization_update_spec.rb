require 'spec_helper'
require 'actions/organization_update'

module VCAP::CloudController
  RSpec.describe OrganizationUpdate do
    describe 'update' do
      let(:org) { FactoryBot.create(:organization, name: 'old-org-name') }

      context 'when a name and label are requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({
            name: 'new-org-name',
            metadata: {
              labels: {
                freaky: 'wednesday',
              },
              annotations: {
                hello: 'there'
              }
            },
          })
        end

        it 'updates a organization' do
          updated_org = OrganizationUpdate.new.update(org, message)
          expect(updated_org.reload.name).to eq 'new-org-name'
        end

        it 'updates metadata' do
          updated_org = OrganizationUpdate.new.update(org, message)
          updated_org.reload
          expect(updated_org.labels.first.key_name).to eq 'freaky'
          expect(updated_org.labels.first.value).to eq 'wednesday'
          expect(updated_org.annotations.first.key).to eq 'hello'
          expect(updated_org.annotations.first.value).to eq 'there'
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(org).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              OrganizationUpdate.new.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'blork is busted')
          end
        end

        context 'when the org name is not unique' do
          it 'errors usefully' do
            FactoryBot.create(:organization, name: 'new-org-name')

            expect {
              OrganizationUpdate.new.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'Name must be unique')
          end
        end
      end

      context 'when nothing is requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({})
        end

        it 'does not change the organization name' do
          updated_org = OrganizationUpdate.new.update(org, message)
          expect(updated_org.reload.name).to eq 'old-org-name'
        end

        it 'does not change labels' do
          updated_org = OrganizationUpdate.new.update(org, message)
          expect(updated_org.reload.labels).to be_empty
        end
      end
    end
  end
end
