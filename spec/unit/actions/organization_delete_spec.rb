require 'spec_helper'
require 'actions/organization_delete'
require 'actions/space_delete'

module VCAP::CloudController
  RSpec.describe OrganizationDelete do
    let(:services_event_repository) { Repositories::ServiceEventRepository.new(user_audit_info) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:space_delete) { SpaceDelete.new(user_audit_info, services_event_repository) }
    subject(:org_delete) { OrganizationDelete.new(space_delete, user_audit_info) }

    describe '#delete' do
      let!(:org_1) { Organization.make }
      let!(:org_2) { Organization.make }
      let!(:org_3) { Organization.make }
      let!(:space) { Space.make(organization: org_1) }
      let!(:space_2) { Space.make(organization: org_1) }
      let!(:space_3) { Space.make(organization: org_3) }
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:app_2) { AppModel.make(space_guid: space_3.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space) }
      let!(:service_instance_2) { ManagedServiceInstance.make(space: space_2) }
      let!(:private_domain_1) { PrivateDomain.make(owning_organization: org_1) }
      let!(:private_domain_2) { PrivateDomain.make(owning_organization: org_2) }
      let!(:service_broker) { ServiceBroker.make }
      let!(:service) { Service.make(service_broker: service_broker) }
      let!(:service_plan) { ServicePlan.make(service: service) }
      let!(:service_plan_visibility) do
        ServicePlanVisibility.make(organization_guid: org_1.guid, service_plan_guid: service_plan.guid)
      end
      let!(:space_quota_definition) { SpaceQuotaDefinition.make(organization: org_1) }
      let!(:isolation_segment) { IsolationSegmentModel.make(organization_guids: [org_1.guid]) }
      let!(:user_1) { User.make }

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

        it 'deletes owned private domains' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { PrivateDomain.count }.by(-2)
          expect { private_domain_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { private_domain_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'unshares private domains which are shared with it but not owned by it' do
          private_domain_2.add_shared_organization(org_1)
          expect(private_domain_2.shared_with?(org_1)).to eq(true)

          org_delete.delete([org_1])

          private_domain_2.refresh
          expect(private_domain_2.shared_with?(org_1)).to eq(false)
        end

        it 'deletes service plan visibilities' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { ServicePlanVisibility.count }.by(-1)
          expect { service_plan_visibility.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes owned space quota definitions' do
          expect {
            org_delete.delete(org_dataset)
          }.to change { SpaceQuotaDefinition.count }.by(-1)
          expect { space_quota_definition.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'disassociates isolation segments' do
          org_delete.delete([org_1])
          isolation_segment.refresh

          expect(isolation_segment.organizations).not_to include(org_1)
        end

        it 'deletes org user roles' do
          org_1.add_user(user_1)
          expect(user_1.organizations).to include(org_1)
          role = OrganizationUser.find(user_id: user_1.id, organization_id: org_1.id)

          org_delete.delete([org_1])
          expect(user_1.reload.organizations).not_to include(org_1)
          expect { role.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'deletes org auditor roles' do
          org_1.add_auditor(user_1)
          expect(user_1.audited_organizations).to include(org_1)
          role = OrganizationAuditor.find(user_id: user_1.id, organization_id: org_1.id)

          org_delete.delete([org_1])
          expect(user_1.reload.audited_organizations).not_to include(org_1)
          expect { role.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'deletes org manager roles' do
          org_1.add_manager(user_1)
          expect(user_1.managed_organizations).to include(org_1)
          role = OrganizationManager.find(user_id: user_1.id, organization_id: org_1.id)

          org_delete.delete([org_1])
          expect(user_1.reload.managed_organizations).not_to include(org_1)
          expect { role.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'deletes org billing manager roles' do
          org_1.add_billing_manager(user_1)
          expect(user_1.billing_managed_organizations).to include(org_1)
          role = OrganizationBillingManager.find(user_id: user_1.id, organization_id: org_1.id)

          org_delete.delete([org_1])
          expect(user_1.reload.billing_managed_organizations).not_to include(org_1)
          expect { role.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'creates audit events for org deletion and recursive deletes' do
          org_delete.delete([org_3])
          expect(VCAP::CloudController::Event.count).to eq(3)
          org_delete_event = VCAP::CloudController::Event.where(type: 'audit.organization.delete-request').last
          expect(org_delete_event.values).to include(
            type: 'audit.organization.delete-request',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            actee: org_3.guid,
            actee_type: 'organization',
            actee_name: org_3.name,
            organization_guid: org_3.guid
          )
          expect(org_delete_event.metadata).to eq({ 'request' => { 'recursive' => true } })

          app_delete_event = VCAP::CloudController::Event.where(type: 'audit.app.delete-request').last
          expect(app_delete_event.values).to include(
            type: 'audit.app.delete-request',
            actee: app_2.guid,
            actee_type: 'app',
          )

          space_delete_event = VCAP::CloudController::Event.where(type: 'audit.space.delete-request').last
          expect(space_delete_event.values).to include(
            type: 'audit.space.delete-request',
            actee: space_3.guid,
            actee_type: 'space',
          )
        end

        context 'when owned private domains are shared with other orgs' do
          let!(:shared_with_org) { Organization.make }

          before do
            private_domain_1.add_shared_organization(shared_with_org)
          end

          it 'returns a helpful error and does not delete the org' do
            errors = []
            expect {
              errors = org_delete.delete([org_1])
            }.not_to change { Organization.count }

            expect(errors.length).to eq(1)
            expect(errors[0].message).to match("Domain '#{private_domain_1.name}' is shared with other organizations. Unshare before deleting.")
          end
        end
      end
    end
  end
end
