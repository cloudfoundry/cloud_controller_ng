require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingModel do
    describe '#process' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:web_process) do
        VCAP::CloudController::ProcessModel.make(
          app: app_model,
          command: 'old command!',
          instances: 3,
          type: VCAP::CloudController::ProcessTypes::WEB,
          created_at: Time.now - 24.hours
        )
      end
      let!(:newer_web_process) do
        VCAP::CloudController::ProcessModel.make(
          app: app_model,
          command: 'new command!',
          instances: 4,
          type: VCAP::CloudController::ProcessTypes::WEB,
          created_at: Time.now - 23.hours
        )
      end

      it 'returns the newest process for the given type to maintain backwards compatibility with v2' do
        route_mapping = RouteMappingModel.make(app: app_model, route: route, process_type: web_process.type)
        expect(route_mapping.process.guid).to eq(newer_web_process.guid)
      end
    end

    describe '#presented_port' do
      let!(:app) { VCAP::CloudController::AppModel.make }
      let!(:app_docker) { VCAP::CloudController::AppModel.make(:docker, droplet: droplet_docker) }
      let!(:app_docker_without_process) { VCAP::CloudController::AppModel.make(:docker, droplet: droplet_docker) }
      let!(:unstaged_app_docker) { VCAP::CloudController::AppModel.make(:docker, droplet: nil) }
      let!(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'some-type') }
      let!(:unstaged_process) { VCAP::CloudController::ProcessModel.make(app: unstaged_app_docker, type: 'test') }
      let!(:route) { VCAP::CloudController::Route.make(space: app.space) }
      let!(:process_docker) { VCAP::CloudController::ProcessModel.make(app: app_docker, type: 'some-type') }
      let!(:route_docker) { VCAP::CloudController::Route.make(space: app_docker.space) }
      let!(:droplet_docker) do
        VCAP::CloudController::DropletModel.make(
          :docker,
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}]}'
        )
      end

      context 'destination for buildpack app with specified port' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app,
            app_port: 1234,
            route: route,
            process_type: process.type,
            weight: 55
          )
        end

        it 'uses app port as presented port' do
          expect(route_mapping.presented_port).to eq(route_mapping.app_port)
        end
      end

      context 'destination for staged docker app' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app_docker,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: process.type,
            weight: 55
          )
        end

        it 'uses the port from the execution metadata as presented port' do
          expect(route_mapping.presented_port).to eq(1024)
        end
      end

      context 'destination for unstaged docker app' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: unstaged_app_docker,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: unstaged_process.type,
            weight: 55
          )
        end

        it 'uses default HTTP port as presented port' do
          expect(route_mapping.presented_port).to eq(8080)
        end
      end

      context 'destination for staged docker app without process' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app_docker_without_process,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: 'web',
            weight: 55
          )
        end

        it 'uses the port from the execution metadata as presented port' do
          expect(route_mapping.presented_port).to eq(1024)
        end
      end
    end

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

      it 'validates that a weight is either between 1 and 100' do
        valid_route_mapping_opts = { app: app_model, route: route, process_type: 'something', app_port: 1000, weight: 1000 }

        expect {
          RouteMappingModel.make(valid_route_mapping_opts)
        }.to raise_error(Sequel::ValidationFailed, /must be between 1 and 100/)
      end

      it 'validates the weight can be nil' do
        valid_route_mapping_opts = { app: app_model, route: route, process_type: 'something', app_port: 1000, weight: nil }

        expect {
          RouteMappingModel.make(valid_route_mapping_opts)
        }.to change { RouteMappingModel.count }.by(1)
      end

      describe 'copilot integration', isolation: :truncation do
        before do
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
