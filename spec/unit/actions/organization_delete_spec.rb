require 'spec_helper'
require 'actions/organization_delete'

module VCAP::CloudController
  describe OrganizationDelete do
    subject(:org_delete) { OrganizationDelete.new({ guid: [org_1.guid, org_2.guid] }, user, user_email) }

    describe '#delete' do
      let!(:org_1) { Organization.make }
      let!(:org_2) { Organization.make }
      let!(:space) { Space.make(organization: org_1) }
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space) }

      let!(:org_dataset) { Organization.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_deprovision(service_instance)
      end

      context 'when the org exists' do
        it 'deletes the org record' do
          expect {
            org_delete.delete
          }.to change { Organization.count }.by(-2)
          expect { org_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { org_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      describe 'recursive deletion' do
        it 'deletes any spaces in the org' do
          expect {
            org_delete.delete
          }.to change { Space.count }.by(-1)
          expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated apps' do
          expect {
            org_delete.delete
          }.to change { AppModel.count }.by(-1)
          expect { app.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated service instances' do
          expect {
            org_delete.delete
          }.to change { ServiceInstance.count }.by(-1)
          expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end
    end

    describe '.for_organization_guid' do
      let!(:org) { Organization.make }
      let!(:space_1) { Space.make(organization: org) }
      let!(:space_2) { Space.make(organization: org) }

      it 'returns a new OrganizationDelete for the org' do
        action = OrganizationDelete.for_organization(org)
        expect { action.delete }.to change { Organization.count }.by(-1)
      end
    end
  end
end
