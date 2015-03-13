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

      let!(:space_dataset) { Space.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_deprovision(service_instance)
      end

      context 'when the space exists' do
        it 'deletes the space record' do
          expect {
            space_delete.delete(space_dataset)
          }.to change { Space.count }.by(-2)
          expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      context 'when the user does not exist' do
        before do
          user.destroy
        end

        it 'raises a UserNotFoundError' do
          expect { space_delete.delete(space_dataset) }.to raise_error VCAP::Errors::ApiError, /user could not be found/
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
      end
    end
  end
end
