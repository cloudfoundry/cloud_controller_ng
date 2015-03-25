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
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space) }

      let!(:org_dataset) { Organization.where(guid: [org_1.guid, org_2.guid]) }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_deprovision(service_instance)
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

      context 'when the user does not exist' do
        before do
          user.destroy
        end

        it 'returns a DeletionError' do
          expect(org_delete.delete(org_dataset)[0]).to be_instance_of(UserNotFoundDeletionError)
        end
      end

      describe 'recursive deletion' do
        it 'deletes any spaces in the org' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { Space.count }.by(-1)
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
          }.to change { ServiceInstance.count }.by(-1)
          expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        context 'when the space deleter returns errors' do
          it 'returns any errors that it received' do
            stub_deprovision(service_instance, status: 500)
            errors = org_delete.delete(org_dataset)
            expect(errors.first).to be_instance_of(VCAP::Errors::ApiError)
          end
        end
      end
    end
  end
end
