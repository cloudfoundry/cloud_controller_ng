require 'spec_helper'
require 'actions/destination_delete'

module VCAP::CloudController
  RSpec.describe DestinationDeleteAction do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:user_header) { headers_for(user) }

    describe '#delete' do
      let!(:destination) do
        RouteMappingModel.make(
          app: app,
          route: route,
          process_type: 'worker'
        )
      end

      it 'deletes the route mapping record' do
        expect {
          DestinationDeleteAction.delete(destination)
        }.to change { RouteMappingModel.count }.by(-1)
        expect { destination.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'copilot integration' do
        before do
          allow(Copilot::Adapter).to receive(:unmap_route)
        end

        it 'delegates to the copilot handler to notify copilot' do
          DestinationDeleteAction.delete(destination)
          expect(Copilot::Adapter).to have_received(:unmap_route).with(destination)
        end
      end
    end
  end
end
