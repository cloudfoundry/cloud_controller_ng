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
          RouteMappingModel.make(invalid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /app_port presence/)
      end

      it 'validates uniqueness across app_guid, route_guid, process_type, and app_port' do
        valid_route_mapping_opts = { app: app_model, route: route, process_type: 'buckeyes', app_port: -1 }
        RouteMappingModel.make(valid_route_mapping_opts)

        expect {
          RouteMappingModel.make(valid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /app_guid and route_guid and process_type and app_port unique/)
      end

      it 'validates that a weight is either between 1 and 128' do
        valid_route_mapping_opts = { app: app_model, route: route, process_type: 'something', app_port: 1000, weight: 1000 }

        expect {
          RouteMappingModel.make(valid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /must be between 1 and 128/)
      end

      context 'when copilot is disabled', isolation: :truncation do
        before do
          TestConfig.override({ copilot: { enabled: false } })
        end

        context 'on delete' do
          it 'does not talk to copilot' do
            route_mapping = RouteMappingModel.make({
              app: app_model,
              route: route,
              process_type: 'buckeyes',
              app_port: -1
            })
            expect(Copilot::Adapter).to_not receive(:unmap_route)
            route_mapping.destroy
          end
        end
      end

      context 'when copilot is enabled', isolation: :truncation do
        before do
          TestConfig.override({ copilot: { enabled: true } })
          allow(Copilot::Adapter).to receive(:unmap_route)
        end

        context 'on delete' do
          let!(:route_mapping) do
            RouteMappingModel.make({
              app: app_model,
              route: route,
              process_type: 'buckeyes',
              app_port: -1
            })
          end

          it 'unmaps the route in copilot' do
            expect(Copilot::Adapter).to receive(:unmap_route).with(route_mapping)
            route_mapping.destroy
          end

          context 'when the delete is part of a transaction' do
            it 'only executes after the transaction is completed' do
              RouteMappingModel.db.transaction do
                route_mapping.destroy
                expect(Copilot::Adapter).to_not have_received(:unmap_route)
              end
              expect(Copilot::Adapter).to have_received(:unmap_route).with(route_mapping)
            end
          end
        end
      end
    end
  end
end
