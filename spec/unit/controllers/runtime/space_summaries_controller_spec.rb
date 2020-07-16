require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceSummariesController do
    let(:space) { Space.make }
    let(:process) { ProcessModelFactory.make(space: space) }
    let(:app_model) { process.app }
    let!(:first_route) { Route.make(space: space) }
    let!(:second_route) { Route.make(space: space) }
    let(:first_service) { ManagedServiceInstance.make(space: space) }
    let(:second_service) { ManagedServiceInstance.make(space: space) }

    let(:instances_reporters) { double(:instances_reporters) }
    let(:running_instances) { { app_model.guid => 5 } }

    before do
      ServiceBinding.make(app: process.app, service_instance: first_service)
      ServiceBinding.make(app: process.app, service_instance: second_service)

      RouteMappingModel.make(app: process.app, route: first_route, process_type: process.type)
      RouteMappingModel.make(app: process.app, route: second_route, process_type: process.type)

      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_processes).and_return(running_instances)
      allow_any_instance_of(SpaceSummariesController).to receive(:instances_reporters).and_return(instances_reporters)
      process.reload
      set_current_user_as_admin
    end

    describe 'GET /v2/spaces/:id/summary' do
      it 'contains guid and name for the space' do
        get "/v2/spaces/#{space.guid}/summary"
        expect(last_response.status).to eq(200)
        expect(decoded_response['guid']).to eq(space.guid)
        expect(decoded_response['name']).to eq(space.name)
      end

      it 'returns the space apps' do
        get "/v2/spaces/#{space.guid}/summary"
        expected_app_hash = {
          guid: app_model.guid,
          urls: [first_route.uri, second_route.uri],
          routes: [
            first_route.as_summary_json,
            second_route.as_summary_json
          ],
          service_count: 2,
          running_instances: 5
        }.merge(process.to_hash)

        expect(decoded_response['apps'][0]).to include(MultiJson.load(MultiJson.dump(expected_app_hash)))
        expect(decoded_response['apps'][0]['service_names']).to match_array([first_service.name, second_service.name])
      end

      it 'returns the space services' do
        get "/v2/spaces/#{space.guid}/summary"
        expected_services = [
          space.service_instances[0].as_summary_json,
          space.service_instances[1].as_summary_json
        ]
        expect(decoded_response['services']).to eq(MultiJson.load(MultiJson.dump(expected_services)))
      end

      it 'returns service summary for the space, including private service instances' do
        foo_space = Space.make
        private_broker = ServiceBroker.make(space_guid: foo_space.guid)
        service = Service.make(service_broker: private_broker)
        service_plan = ServicePlan.make(service: service, public: false)
        service_instance = ManagedServiceInstance.make(space: space, service_plan: service_plan)

        get "/v2/spaces/#{space.guid}/summary"

        expect(decoded_response['services'].map { |service_json| service_json['guid'] }).to include(service_instance.guid)
      end

      it 'does not return private services from other spaces' do
        other_space = Space.make
        private_broker2 = ServiceBroker.make(space: other_space)
        service2 = Service.make(service_broker: private_broker2)
        service_plan2 = ServicePlan.make(service: service2, public: false)
        service_instance2 = ManagedServiceInstance.make(space: other_space, service_plan: service_plan2)

        get "/v2/spaces/#{space.guid}/summary"

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['services'].map { |service_json| service_json['guid'] }).to_not include service_instance2.guid
      end

      it 'does not include sharing information for not-shared service instances' do
        space = Space.make
        ManagedServiceInstance.make(space: space)

        get "/v2/spaces/#{space.guid}/summary"

        expect(decoded_response['services'].first['shared_from']).to be_nil
      end

      it 'includes the type of all service instances' do
        get "/v2/spaces/#{space.guid}/summary"

        parsed_response = MultiJson.load(last_response.body)
        parsed_response['services'].each do |service_json|
          expect(service_json.fetch('type')).to eq('managed_service_instance')
        end
      end

      context 'when a managed service has been shared into this space' do
        let(:receiver_space) { Space.make }
        let(:originating_space) { Space.make }
        let(:service_instance) { ManagedServiceInstance.make(space: originating_space) }
        let(:services_response) { decoded_response['services'] }

        before do
          service_instance.add_shared_space(receiver_space)

          get "/v2/spaces/#{receiver_space.guid}/summary"
        end

        it 'includes the shared service instance' do
          expect(services_response.map { |service_json| service_json['guid'] }).to include(service_instance.guid)
        end

        it 'includes sharing information' do
          expect(services_response.first).to have_key('shared_from')
          expect(services_response.first['shared_from']).to eq({
            'space_guid' => originating_space.guid,
            'space_name' => originating_space.name,
            'organization_name' => originating_space.organization.name
          })
        end

        it 'does not contain shared to information' do
          expect(services_response.first['shared_to']).to be_empty
        end
      end

      context 'when a managed service instance is shared into another space' do
        let(:host_space) { Space.make }
        let(:service_instance) { ManagedServiceInstance.make(space: host_space) }
        let(:foreign_space) { Space.make }
        let(:services_response) { decoded_response['services'] }

        before(:each) do
          service_instance.add_shared_space(foreign_space)

          get "/v2/spaces/#{host_space.guid}/summary"
        end

        it 'includes shared to information' do
          expect(services_response.first).to have_key('shared_to')
          expect(services_response.first['shared_to'].first).to eq({
            'space_guid' => foreign_space.guid,
            'space_name' => foreign_space.name,
            'organization_name' => foreign_space.organization.name
          })
        end
      end

      context 'when an app is deleted concurrently' do
        let(:deleted_process) { ProcessModelFactory.make(space: space) }
        let!(:deleted_app_guid) { deleted_process.app.guid }
        before do
          deleted_process.app = nil
          allow_any_instance_of(Space).to receive(:apps).and_return([process, deleted_process])
        end

        it 'ignores the process with the deleted app' do
          get "/v2/spaces/#{space.guid}/summary"
          expect(last_response.status).to eq(200)
          expect(space.apps).to match([process, deleted_process])
          expect(last_response.body).not_to include(deleted_app_guid)
        end
      end

      context 'when the app has rolled to a new web process' do
        before do
          process.destroy
          ProcessModel.make(app: app_model, type: ProcessTypes::WEB)
        end

        it 'returns the space apps with the appropriate app guid' do
          get "/v2/spaces/#{space.guid}/summary"

          expect(decoded_response['apps'][0]).to include({ 'guid' => app_model.guid })
        end
      end
    end
  end
end
