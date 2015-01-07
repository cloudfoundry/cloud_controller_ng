require 'spec_helper'

module VCAP::CloudController
  describe SpaceSummariesController do
    let(:space) { Space.make }
    let(:app_obj) { AppFactory.make(space: space) }
    let!(:first_route) { Route.make(space: space, app_guids: [app_obj.guid]) }
    let!(:second_route) { Route.make(space: space, app_guids: [app_obj.guid]) }
    let(:first_service) {  ManagedServiceInstance.make(space: space) }
    let(:second_service) {  ManagedServiceInstance.make(space: space) }

    let(:instances_reporters) { double(:instances_reporters) }
    let(:running_instances) { { app_obj.guid => 5 } }

    before do
      ServiceBinding.make(app: app_obj, service_instance: first_service)
      ServiceBinding.make(app: app_obj, service_instance: second_service)

      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_apps).and_return(running_instances)
      allow_any_instance_of(SpaceSummariesController).to receive(:instances_reporters).and_return(instances_reporters)
      app_obj.reload
    end

    describe 'GET /v2/spaces/:id/summary' do
      it 'contains guid and name for the space' do
        get "/v2/spaces/#{space.guid}/summary", '', admin_headers
        expect(last_response.status).to eq(200)
        expect(decoded_response['guid']).to eq(space.guid)
        expect(decoded_response['name']).to eq(space.name)
      end

      it 'returns the space apps' do
        get "/v2/spaces/#{space.guid}/summary", '', admin_headers
        expected_app_hash = [{
          guid: app_obj.guid,
          urls: [first_route.fqdn, second_route.fqdn],
          routes: [
            first_route.as_summary_json,
            second_route.as_summary_json
          ],
          service_count: 2,
          service_names: [first_service.name, second_service.name],
          running_instances: 5
        }.merge(app_obj.to_hash)]

        expect(decoded_response['apps']).to eq(MultiJson.load(MultiJson.dump(expected_app_hash)))
      end

      it 'returns the space services' do
        get "/v2/spaces/#{space.guid}/summary", '', admin_headers
        expected_services = [
          space.service_instances[0].as_summary_json,
          space.service_instances[1].as_summary_json
        ]
        expect(decoded_response['services']).to eq(MultiJson.load(MultiJson.dump(expected_services)))
      end

      context 'when the instances reporter fails' do
        before do
          allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_apps).and_raise(
            Errors::InstancesUnavailable.new(RuntimeError.new('something went wrong.')))
        end

        it "returns '220001 InstancesError'" do
          get "/v2/spaces/#{space.guid}/summary", '', admin_headers

          expect(last_response.status).to eq(503)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['code']).to eq(220002)
          expect(parsed_response['description']).to eq('Instances information unavailable: something went wrong.')
        end
      end
    end
  end
end
