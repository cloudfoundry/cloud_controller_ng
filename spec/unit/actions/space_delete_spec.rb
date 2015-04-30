require 'spec_helper'
require 'actions/space_delete'

module VCAP::CloudController
  describe SpaceDelete do
    subject(:space_delete) { SpaceDelete.new(user.id, user_email) }

    describe '#delete' do
      let!(:space) { Space.make }
      let!(:space_2) { Space.make }
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space_2) }

      let(:space_dataset) { Space.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_deprovision(service_instance, accepts_incomplete: true)
      end

      context 'when the space exists' do
        it 'deletes the space record' do
          expect {
            space_delete.delete(space_dataset)
          }.to change { Space.count }.by(-2)
          expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      describe 'recursive deletion' do
        it 'deletes associated apps' do
          expect {
            space_delete.delete(space_dataset)
          }.to change { AppModel.count }.by(-1)
          expect { app.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated service instances' do
          expect {
            space_delete.delete(space_dataset)
          }.to change { ServiceInstance.count }.by(-1)
          expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        context 'when deletion of a service instance is "in progress"' do
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

            expect(results.first.message).to include("Deletion of space #{space_3.name} failed because one or more resources within could not be deleted.")
            expect(results.first.message).to include("\tThe service broker returned an invalid response for the request to #{instance_1_url}")
            expect(results.first.message).to include("\tThe service broker returned an invalid response for the request to #{instance_2_url}")

            expect(results.second.message).to include("Deletion of space #{space_4.name} failed because one or more resources within could not be deleted.")
            expect(results.second.message).to include("\tThe service broker returned an invalid response for the request to #{instance_4_url}")
          end
        end
      end
    end
  end
end
