require 'spec_helper'
require 'actions/space_delete'

module VCAP::CloudController
  describe SpaceDelete do
    subject(:space_delete) { SpaceDelete.new(user.id, user_email, services_event_repository) }
    let(:services_event_repository) { Repositories::Services::EventRepository.new(user: user, user_email: user_email) }

    describe '#delete' do
      let!(:space) { Space.make }
      let!(:space_2) { Space.make }
      let!(:app) { AppModel.make(space_guid: space.guid) }

      let(:space_dataset) { Space.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      it 'deletes the space record' do
        expect {
          space_delete.delete(space_dataset)
        }.to change { Space.count }.by(-2)
        expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
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

          it 'are deleted' do
            expect {
              space_delete.delete(space_dataset)
            }.to change { ServiceInstance.count }.by(-1)
            expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
          end

          context 'when deletion of service instances fail' do
            let!(:space_3) { Space.make }
            let!(:space_4) { Space.make }

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
              expect(results.first).to be_instance_of(VCAP::Errors::ApiError)
              expect(results.second).to be_instance_of(VCAP::Errors::ApiError)

              instance_1_url = remove_basic_auth(deprovision_url(service_instance_1))
              instance_2_url = remove_basic_auth(deprovision_url(service_instance_2))
              instance_4_url = remove_basic_auth(deprovision_url(service_instance_4))

              expect(results.first.message).
                to include("Deletion of space #{space_3.name} failed because one or more resources within could not be deleted.")
              expect(results.first.message).
                to include("\tService instance #{service_instance_1.name}: The service broker returned an invalid response for the request to #{instance_1_url}")
              expect(results.first.message).
                to include("\tService instance #{service_instance_2.name}: The service broker returned an invalid response for the request to #{instance_2_url}")

              expect(results.second.message).
                to include("Deletion of space #{space_4.name} failed because one or more resources within could not be deleted.")
              expect(results.second.message).
                to include("\tService instance #{service_instance_4.name}: The service broker returned an invalid response for the request to #{instance_4_url}")
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
              expect(result).to be_instance_of(VCAP::Errors::ApiError)
              expect(result.message).to include("An operation for service instance #{service_instance.name} is in progress.")
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
                error = [VCAP::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'fake-name')]
                service_instance_delete = instance_double(ServiceInstanceDelete, delete: error)
                allow(ServiceInstanceDelete).to receive(:new).and_return(service_instance_delete)
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
      end
    end
  end
end
