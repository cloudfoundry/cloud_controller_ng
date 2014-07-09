require 'spec_helper'

module VCAP::CloudController
  describe SpaceSummariesController do
    let(:space) { Space.make }
    let(:app_obj) { AppFactory.make(space: space) }
    let!(:first_route) { Route.make(space: space, app_guids: [app_obj.guid]) }
    let!(:second_route) { Route.make(space: space, app_guids: [app_obj.guid]) }
    let(:first_service) {  ManagedServiceInstance.make(space: space) }
    let(:second_service) {  ManagedServiceInstance.make(space: space) }

    let(:instances_reporter_factory) { double(:instances_reporter_factory) }
    let(:instances_reporter) { double(:instances_reporter) }
    let(:running_instances) { 5 }

    before do
      ServiceBinding.make(app: app_obj, service_instance: first_service)
      ServiceBinding.make(app: app_obj, service_instance: second_service)

      allow(instances_reporter_factory).to receive(:instances_reporter_for_app).and_return(instances_reporter)
      allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).
        and_return(running_instances)
      allow_any_instance_of(SpaceSummariesController).to receive(:instances_reporter_factory).and_return(instances_reporter_factory)
      app_obj.reload
    end

    describe 'GET /v2/spaces/:id/summary' do
      it "contains guid and name for the space" do
        get "/v2/spaces/#{space.guid}/summary", "", admin_headers
        expect(last_response.status).to eq(200)
        expect(decoded_response["guid"]).to eq(space.guid)
        expect(decoded_response["name"]).to eq(space.name)
      end

      it "returns the space apps" do
        get "/v2/spaces/#{space.guid}/summary", "", admin_headers
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

        expect(decoded_response["apps"]).to eq(Yajl::Parser.parse(Yajl::Encoder.encode(expected_app_hash)))
      end

      it "returns the space services" do
        get "/v2/spaces/#{space.guid}/summary", "", admin_headers
        expected_services = [
          space.service_instances[0].as_summary_json,
          space.service_instances[1].as_summary_json
        ]
        expect(decoded_response["services"]).to eq(Yajl::Parser.parse(Yajl::Encoder.encode(expected_services)))
      end
    end
  end
end
