require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceSummariesController do
    let(:space) { Space.make }
    let(:app_obj) { AppFactory.make(space: space) }
    let!(:first_route) { Route.make(space: space) }
    let!(:second_route) { Route.make(space: space) }
    let(:first_service) { ManagedServiceInstance.make(space: space) }
    let(:second_service) { ManagedServiceInstance.make(space: space) }

    let(:instances_reporters) { double(:instances_reporters) }
    let(:running_instances) { { app_obj.guid => 5 } }

    before do
      ServiceBinding.make(app: app_obj.app, service_instance: first_service)
      ServiceBinding.make(app: app_obj.app, service_instance: second_service)

      RouteMappingModel.make(app: app_obj.app, route: first_route, process_type: app_obj.type)
      RouteMappingModel.make(app: app_obj.app, route: second_route, process_type: app_obj.type)

      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_processes).and_return(running_instances)
      allow_any_instance_of(SpaceSummariesController).to receive(:instances_reporters).and_return(instances_reporters)
      app_obj.reload
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
          guid: app_obj.guid,
          urls: [first_route.uri, second_route.uri],
          routes: [
            first_route.as_summary_json,
            second_route.as_summary_json
          ],
          service_count: 2,
          running_instances: 5
        }.merge(app_obj.to_hash)

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

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['services'].map { |service_json| service_json['guid'] }).to include(service_instance.guid)
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

      context 'when the instances reporter fails' do
        before do
          allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_processes).and_raise(
            CloudController::Errors::InstancesUnavailable.new(RuntimeError.new('something went wrong.')))
        end

        it "returns '220001 InstancesError'" do
          get "/v2/spaces/#{space.guid}/summary"

          expect(last_response.status).to eq(503)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['code']).to eq(220002)
          expect(parsed_response['description']).to eq('Instances information unavailable: something went wrong.')
        end
      end
    end
  end
end
