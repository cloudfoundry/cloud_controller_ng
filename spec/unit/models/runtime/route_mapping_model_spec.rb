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
            expect(CopilotHandler).to_not receive(:unmap_route)
            route_mapping.destroy
          end
        end
      end

      context 'when copilot is enabled', isolation: :truncation do
        before do
          TestConfig.override({ copilot: { enabled: true } })
          allow(CopilotHandler).to receive(:unmap_route)
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
            expect(CopilotHandler).to receive(:unmap_route).with(route_mapping)
            route_mapping.destroy
          end

          context 'when there is an error communicating with copilot' do
            let(:logger) { instance_double(Steno::Logger, error: nil) }

            it 'logs and swallows the error' do
              allow(CopilotHandler).to receive(:unmap_route).and_raise(CopilotHandler::CopilotUnavailable.new('some-error'))
              allow(Steno).to receive(:logger).and_return(logger)

              expect {
                route_mapping.destroy

                expect(CopilotHandler).to have_received(:unmap_route).with(route_mapping)
                expect(logger).to have_received(:error).with(/failed communicating.*some-error/)
              }.to change { RouteMappingModel.count }.by(-1)
            end
          end

          context 'when the delete is part of a transaction' do
            it 'only executes after the transaction is completed' do
              RouteMappingModel.db.transaction do
                route_mapping.destroy
                expect(CopilotHandler).to_not have_received(:unmap_route)
              end
              expect(CopilotHandler).to have_received(:unmap_route).with(route_mapping)
            end
          end
        end
      end
    end
  end
end
