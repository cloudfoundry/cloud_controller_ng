require 'spec_helper'
require 'actions/organization_delete'
require 'actions/space_delete'

module VCAP::CloudController
  describe OrganizationDelete do
    let(:space_delete) { SpaceDelete.new(user.id, user_email) }
    subject(:org_delete) { OrganizationDelete.new(space_delete) }

    describe '#delete' do
      let!(:org_1) { Organization.make }
      let!(:org_2) { Organization.make }
      let!(:space) { Space.make(organization: org_1) }
      let!(:space_2) { Space.make(organization: org_1) }
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space) }
      let!(:service_instance_2) { ManagedServiceInstance.make(space: space_2) }

      let!(:org_dataset) { Organization.where(guid: [org_1.guid, org_2.guid]) }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_deprovision(service_instance, accepts_incomplete: true)
        stub_deprovision(service_instance_2, accepts_incomplete: true)
      end

      context 'when the org exists' do
        it 'deletes the org record' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { Organization.count }.by(-2)
          expect { org_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { org_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      describe 'recursive deletion' do
        it 'deletes any spaces in the org' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { Space.count }.by(-2)
          expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated apps' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { AppModel.count }.by(-1)
          expect { app.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated service instances' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { ServiceInstance.count }.by(-2)
          expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        context 'when the space deleter returns errors' do
          before do
            stub_deprovision(service_instance, status: 500, accepts_incomplete: true)
            stub_deprovision(service_instance_2, status: 500, accepts_incomplete: true)
          end
          it 'returns an OrganizationDeletionFailed error' do
            errors = org_delete.delete(org_dataset)
            expect(errors.first).to be_instance_of(VCAP::Errors::ApiError)
            expect(errors.first.name).to eq 'OrganizationDeletionFailed'
          end

          it 'rolls up the error messages of its child deletions' do
            errors = org_delete.delete(org_dataset)
            expect(errors.first.message).to include "Deletion of organization #{org_1.name} failed because one or more resources within could not be deleted.

Deletion of space #{space.name} failed because one or more resources within could not be deleted.

\tService instance #{service_instance.name}: The service broker returned an invalid response for the request"

            expect(errors.first.message).to include "Deletion of space #{space_2.name} failed because one or more resources within could not be deleted.

\tService instance #{service_instance_2.name}: The service broker returned an invalid response for the request"
          end
        end
      end
    end
  end
end
