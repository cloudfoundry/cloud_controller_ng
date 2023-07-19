require 'spec_helper'
require 'actions/v2/organization_delete'
require 'actions/space_delete'

module VCAP::CloudController
  module V2
    RSpec.describe OrganizationDelete do
      let(:services_event_repository) { Repositories::ServiceEventRepository.new(user_audit_info) }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
      let(:space_delete) { SpaceDelete.new(user_audit_info, services_event_repository) }
      subject(:org_delete) { V2::OrganizationDelete.new(space_delete) }
      describe '#delete' do
        let!(:org_1) { Organization.make }
        let!(:org_2) { Organization.make }
        let!(:space) { Space.make(organization: org_1) }
        let!(:space_2) { Space.make(organization: org_1) }
        let!(:app) { AppModel.make(space_guid: space.guid) }
        let!(:service_instance) { ManagedServiceInstance.make(space: space) }
        let!(:service_instance_2) { ManagedServiceInstance.make(space: space_2) }

        let!(:org1_label) do
          OrganizationLabelModel.make(
            key_prefix: 'indiana.edu',
            key_name: 'state',
            value: 'Indiana',
            resource_guid: org_1.guid
          )
        end
        let!(:org1_annotation) do
          OrganizationAnnotationModel.make(
            key: 'city',
            value: 'Monticello',
            resource_guid: org_1.guid
          )
        end

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

          it 'deletes associated metadata' do
            org_delete.delete(org_dataset)
            expect { org1_label.refresh }.to raise_error Sequel::Error, 'Record not found'
            expect { org1_annotation.refresh }.to raise_error Sequel::Error, 'Record not found'
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
        end
      end
    end
  end
end
