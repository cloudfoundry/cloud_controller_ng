require 'spec_helper'
require 'actions/space_delete'

module VCAP::CloudController
  RSpec.describe SpaceDelete do
    subject(:space_delete) { SpaceDelete.new(user_audit_info, services_event_repository) }
    let(:services_event_repository) { Repositories::ServiceEventRepository.new(user_audit_info) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }

    describe '#delete' do
      let!(:space) { Space.make(name: 'space-1') }
      let!(:space_2) { Space.make(name: 'space-2') }
      let!(:app) { AppModel.make(space_guid: space.guid) }

      let(:space_dataset) { Space.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        TestConfig.override(kubernetes: {})
      end

      it 'deletes both space records' do
        expect {
          space_delete.delete(space_dataset)
        }.to change { Space.count }.by(-2)
        expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'creates audit events for recursive app deletion and space deletion' do
        space_delete.delete([space])
        expect(VCAP::CloudController::Event.count).to eq(2)

        events = VCAP::CloudController::Event.all
        event = events.last
        expect(event.values).to include(
          type: 'audit.space.delete-request',
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: space.guid,
          actee_type: 'space',
          actee_name: 'space-1',
          space_guid: space.guid,
          organization_guid: space.organization.guid,
        )
        expect(event.metadata).to eq({ 'request' => { 'recursive' => true } })
        expect(event.timestamp).to be

        event = VCAP::CloudController::Event.first
        expect(event.values).to include(
          type: 'audit.app.delete-request'
        )
      end

      describe 'recursive deletion' do
        it 'deletes associated apps' do
          expect {
            space_delete.delete(space_dataset)
          }.to change { AppModel.count }.by(-1)
          expect { app.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        describe 'service instances' do
          let!(:service_instance) { ManagedServiceInstance.make(space: space_2) }

          before do
            stub_deprovision(service_instance, accepts_incomplete: true)
          end

          it 'deletes service instances' do
            expect {
              space_delete.delete(space_dataset)
            }.to change { ServiceInstance.count }.by(-1)
            expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
          end

          context 'when a service instance is shared to the space' do
            let(:fake_shared_service) { instance_double(ManagedServiceInstance) }

            it 'an unshare event is recorded when the space is deleted' do
              allow(fake_shared_service).to receive(:guid).and_return('some-guid')
              allow(fake_shared_service).to receive(:remove_shared_space)
              allow(space).to receive(:service_instances_shared_from_other_spaces).and_return([fake_shared_service])

              expect(Repositories::ServiceInstanceShareEventRepository).to receive(:record_unshare_event).once

              space_delete.delete([space])
            end
          end

          context 'when deletion of service instances fail' do
            let!(:space_3) { Space.make(name: 'space-3') }
            let!(:space_4) { Space.make(name: 'space-4') }

            let!(:service_instance_1) { ManagedServiceInstance.make(space: space_3) } # deletion fail
            let!(:service_instance_2) { ManagedServiceInstance.make(space: space_3) } # deletion fail
            let!(:service_instance_3) { ManagedServiceInstance.make(space: space_3) } # deletion succeeds
            let!(:service_instance_4) { ManagedServiceInstance.make(space: space_4) } # deletion fail

            before do
              stub_deprovision(service_instance_1, accepts_incomplete: true, status: 500)
              stub_deprovision(service_instance_2, accepts_incomplete: true, status: 500)
              stub_deprovision(service_instance_3, accepts_incomplete: true)
              stub_deprovision(service_instance_4, accepts_incomplete: true, status: 500)
            end

            it 'deletes other spaces' do
              space_delete.delete(space_dataset)

              expect(space.exists?).to be_falsey
              expect(space_2.exists?).to be_falsey
              expect(space_4.exists?).to be_truthy
            end

            it 'deletes the other instances' do
              expect {
                space_delete.delete(space_dataset)
              }.to change { ServiceInstance.count }.by(-2)
              expect { service_instance_1.refresh }.not_to raise_error
              expect { service_instance_2.refresh }.not_to raise_error
              expect { service_instance_3.refresh }.to raise_error Sequel::Error, 'Record not found'
            end

            it 'returns a service broker bad response error' do
              results = space_delete.delete(space_dataset)
              expect(results.length).to eq(2)
              expect(results.first).to be_instance_of(CloudController::Errors::ApiError)
              expect(results.second).to be_instance_of(CloudController::Errors::ApiError)

              results_messages = results.map(&:message).join(' ')
              expect(results_messages).
                to include("Deletion of space #{space_3.name} failed because one or more resources within could not be deleted.")
              expect(results_messages).
                to include("\tService instance #{service_instance_1.name}: The service broker returned an invalid response.")
              expect(results_messages).
                to include("\tService instance #{service_instance_2.name}: The service broker returned an invalid response.")

              expect(results_messages).
                to include("Deletion of space #{space_4.name} failed because one or more resources within could not be deleted.")
              expect(results_messages).
                to include("\tService instance #{service_instance_4.name}: The service broker returned an invalid response.")
            end
          end

          context 'when unsharing a service instance that has been shared to the space fails' do
            let(:other_space) { Space.make }
            let(:fake_shared_service) { instance_double(ManagedServiceInstance) }

            before do
              allow(fake_shared_service).to receive(:guid).and_return('some-guid')
              allow(space).to receive(:service_instances_shared_from_other_spaces).and_return([fake_shared_service])
              allow(fake_shared_service).to receive(:remove_shared_space).and_raise('Cannot unshare')
            end

            it 'returns an error message indicating that the unshare failed' do
              errors = space_delete.delete([space])

              expect(errors.length).to eq(1)
              expect(errors.first).to be_instance_of(CloudController::Errors::ApiError)
              expect(errors.first.message).to include 'Cannot unshare'
            end

            it 'does not record an unshare event' do
              expect(Repositories::ServiceInstanceShareEventRepository).not_to receive(:record_unshare_event)
              space_delete.delete([space])
            end

            it 'fails to delete the space because instances are not yet unshared' do
              space_delete.delete([space])
              expect { space.refresh }.not_to raise_error
            end
          end

          context 'when deletion of a service instance is "in progress"' do
            let!(:service_instance) { ManagedServiceInstance.make(space: space_2) }

            before do
              stub_deprovision(service_instance, accepts_incomplete: true, status: 202)
            end

            it 'fails to delete the space because instances are not yet deleted' do
              result = space_delete.delete(space_dataset)
              expect { service_instance.refresh }.not_to raise_error
              expect(result.length).to be(1)

              result = result.first
              expect(result).to be_instance_of(CloudController::Errors::ApiError)
              expect(result.message).to include("An operation for service instance #{service_instance.name} is in progress.")
            end

            it 'enqueues a job to poll the service instance and remove it' do
              space_delete.delete(space_dataset)

              stub_request(:get, last_operation_state_url(service_instance)).
                to_return(status: 410, body: '{}')

              # There's a delete buildpack cache job scheduled as well
              execute_all_jobs(expected_successes: 2, expected_failures: 0)

              expect(ServiceInstance.all).not_to include(service_instance)
            end

            context 'and there are multiple service instances deprovisioned with accepts_incomplete' do
              let!(:service_instance_2) { ManagedServiceInstance.make(space: space) } # deletion fail

              before do
                stub_deprovision(service_instance_2, accepts_incomplete: true, status: 202)
              end

              it 'returns an error message for each service instance' do
                result = space_delete.delete(space_dataset)
                expect { service_instance.refresh }.not_to raise_error
                expect { service_instance_2.refresh }.not_to raise_error
                expect(result.length).to be(2)

                message = result.map(&:message).join("\n")
                expect(message).to include("An operation for service instance #{service_instance.name} is in progress.")
                expect(message).to include("An operation for service instance #{service_instance_2.name} is in progress.")
              end
            end
          end
        end

        context 'when private brokers are associated with the space' do
          let!(:service_to_be_deleted)      { VCAP::CloudController::Service.make(service_broker: broker_to_be_deleted) }
          let!(:service_plan_to_be_deleted) { VCAP::CloudController::ServicePlan.make(service: service_to_be_deleted) }
          let!(:broker_to_be_deleted)       { VCAP::CloudController::ServiceBroker.make(space_guid: space.guid) }
          let!(:broker_to_be_deleted2) { VCAP::CloudController::ServiceBroker.make(space_guid: space.guid) }
          let!(:service_instance_to_be_deleted) { ManagedServiceInstance.make(space: space, service_plan: service_plan_to_be_deleted) }

          before do
            stub_deprovision(service_instance_to_be_deleted, accepts_incomplete: true)
          end

          it 'deletes associated private brokers' do
            allow(broker_to_be_deleted).to receive(:destroy)
            expect(ServiceBroker.find(guid: broker_to_be_deleted.guid)).to eq broker_to_be_deleted

            expect {
              space_delete.delete(Space.where(guid: space.guid))
            }.to change { Space.count }.by(-1)

            expect(ServiceBroker.find(guid: broker_to_be_deleted.guid)).to be nil
          end

          context 'when the private brokers have service instances' do
            it 'deletes associated private brokers' do
              expect(ServiceBroker.find(guid: broker_to_be_deleted.guid)).to eq broker_to_be_deleted

              expect {
                space_delete.delete(Space.where(guid: space.guid))
              }.to change { Space.count }.by(-1)

              expect(ServiceBroker.find(guid: broker_to_be_deleted.guid)).to be nil
            end

            context 'when deleting a service instance associated with a private broker fails' do
              before do
                service_instance_delete = instance_double(V3::ServiceInstanceDelete)
                allow(service_instance_delete).
                  to receive(:delete).and_raise(CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'fake-name'))
                allow(V3::ServiceInstanceDelete).to receive(:new).and_return(service_instance_delete)
              end

              it 'deletes all but the associated broker' do
                expect(ServiceBroker.find(guid: broker_to_be_deleted.guid)).to eq broker_to_be_deleted

                expect {
                  space_delete.delete(Space.where(guid: space.guid))
                }.to change { ServiceBroker.count }.by(-1)
                expect { broker_to_be_deleted.refresh }.not_to raise_error
                expect { broker_to_be_deleted2.refresh }.to raise_error Sequel::Error, 'Record not found'
              end

              it 'displays the name of the private broker in the errors list along with its associated instance' do
                errors = space_delete.delete(Space.where(guid: space.guid))

                expect(errors.map(&:name)).to include('SpaceDeletionFailed', 'SpaceDeletionFailed')
                expect(errors.map(&:message).join).to match(/service instance fake-name is in progress/)
                expect(errors.map(&:message).join).to match(/associated service instances: #{broker_to_be_deleted.name}/)
              end
            end
          end
        end

        describe 'routes and route mappings' do
          let!(:process) { ProcessModel.make app: app, type: 'web' }
          let!(:route) { Route.make space: space }

          it 'deletes routes in the space (by way of model association dependency)' do
            expect(route.exists?).to be true
            expect {
              space_delete.delete(space_dataset)
            }.to change { Route.count }.by(-1)
          end
        end

        describe 'label deletion' do
          let!(:space_label) do
            VCAP::CloudController::SpaceLabelModel.make(
              key_name: 'release',
              value: 'stable',
              resource_guid: space.guid
            )
          end
          let!(:space2_label) do
            VCAP::CloudController::SpaceLabelModel.make(
              key_name: 'release',
              value: 'stable',
              resource_guid: space_2.guid
            )
          end

          it 'deletes associated space labels' do
            expect {
              space_delete.delete(space_dataset)
            }.to change { SpaceLabelModel.count }.by(-2)
            expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
          end
        end

        describe 'roles' do
          let(:user_with_role) { User.make }

          before do
            space.organization.add_user(user_with_role)
          end

          it 'deletes space developer roles' do
            space.add_developer(user_with_role)
            expect(user_with_role.spaces).to include(space)
            role = SpaceDeveloper.find(user_id: user_with_role.id, space_id: space.id)
            expect(role).not_to be_nil

            space_delete.delete([space])
            expect(user_with_role.reload.spaces).not_to include(space)
            expect { role.reload }.to raise_error Sequel::NoExistingObject

            organization_user = OrganizationUser.find(user_id: user_with_role.id, organization_id: space.organization_id)
            expect(organization_user).not_to be_nil
          end

          it 'deletes space auditor roles' do
            space.add_auditor(user_with_role)
            expect(user_with_role.audited_spaces).to include(space)
            role = SpaceAuditor.find(user_id: user_with_role.id, space_id: space.id)
            expect(role).not_to be_nil

            space_delete.delete([space])
            expect(user_with_role.reload.audited_spaces).not_to include(space)
            expect { role.reload }.to raise_error Sequel::NoExistingObject

            organization_user = OrganizationUser.find(user_id: user_with_role.id, organization_id: space.organization_id)
            expect(organization_user).not_to be_nil
          end

          it 'deletes space manager roles' do
            space.add_manager(user_with_role)
            expect(user_with_role.managed_spaces).to include(space)
            role = SpaceManager.find(user_id: user_with_role.id, space_id: space.id)
            expect(role).not_to be_nil

            space_delete.delete([space])
            expect(user_with_role.reload.managed_spaces).not_to include(space)
            expect { role.reload }.to raise_error Sequel::NoExistingObject

            organization_user = OrganizationUser.find(user_id: user_with_role.id, organization_id: space.organization_id)
            expect(organization_user).not_to be_nil
          end
        end
      end
    end
  end
end
