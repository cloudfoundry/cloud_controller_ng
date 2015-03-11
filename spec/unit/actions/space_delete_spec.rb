require 'spec_helper'
require 'actions/space_delete'

module VCAP::CloudController
  describe SpaceDelete do
    subject(:space_delete) { SpaceDelete.new({}, user, user_email) }

    describe '#delete' do
      let!(:space) { Space.make }
      let!(:space_2) { Space.make }
      let!(:app) { AppModel.make(space_guid: space.guid) }
      let!(:service_instance) { ManagedServiceInstance.make(space: space_2) }

      let!(:space_dataset) { Space.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        attrs = service_instance.client.attrs
        uri = URI(attrs[:url])
        uri.user = attrs[:auth_username]
        uri.password = attrs[:auth_password]

        plan = service_instance.service_plan
        service = plan.service

        uri = uri.to_s
        uri += "/v2/service_instances/#{service_instance.guid}"
        stub_request(:delete, uri + "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}").to_return(status: 200, body: '{}')
      end

      context 'when the space exists' do
        it 'deletes the space record' do
          expect {
            space_delete.delete
          }.to change { Space.count }.by(-2)
          expect { space.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      describe 'recursive deletion' do
        it 'deletes associated apps' do
          expect {
            space_delete.delete
          }.to change { AppModel.count }.by(-1)
          expect { app.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated service instances' do
          expect {
            space_delete.delete
          }.to change { ServiceInstance.count }.by(-1)
          expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end
    end

    describe '.for_space_guid' do
      let!(:space) { Space.make }

      it 'returns a new SpaceDelete for the given space guid' do
        action = SpaceDelete.for_space(space)
        expect { action.delete }.to change { Space.count }.by(-1)
      end
    end

    describe '.for_organization_guid' do
      let!(:org) { Organization.make }
      let!(:space_1) { Space.make(organization: org) }
      let!(:space_2) { Space.make(organization: org) }

      it 'returns a new SpaceDelete for the all the spaces in the org with the given guid' do
        action = SpaceDelete.for_organization(org)
        expect { action.delete }.to change { Space.count }.by(-2)
      end
    end
  end
end
