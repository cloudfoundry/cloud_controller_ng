require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingModel do
    describe 'validations' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

      it 'must define an app_port' do
        invalid_route_mapping_opts = { app: app_model, route: route, process_type: 'buckeyes', app_port: nil }
        expect {
          described_class.make(invalid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /app_port presence/)
      end

      it 'validates uniqueness across app_guid, route_guid, process_type, and app_port' do
        valid_route_mapping_opts = { app: app_model, route: route, process_type: 'buckeyes', app_port: -1 }
        described_class.make(valid_route_mapping_opts)

        expect {
          described_class.make(valid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /app_guid and route_guid and process_type and app_port unique/)
      end
    end
  end
end
