require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummariesController, type: :controller do
    let(:mem_size) { 128 }
    let(:space) { Space.make }
    let(:routes) { 2.times.map { Route.make(:space => space) } }
    let(:services) { 2.times.map { ManagedServiceInstance.make(:space => space) } }

    let(:started_app) do
      AppFactory.make(
        space: space,
        instances: 2,
        memory: mem_size,
        state: "STARTED",
        package_hash: "abc",
        package_state: "STAGED",
      )
    end

    let(:stopped_app) do
      AppFactory.make(
        :space => space,
        :instances => 3,
        :memory => mem_size,
        :state => "STOPPED",
      )
    end

    let(:apps) { [started_app, stopped_app]}

    before do
      routes.each do |route|
        started_app.add_route(route)
        stopped_app.add_route(route)
      end

      services.each do |service|
        ServiceBinding.make(:app => started_app, :service_instance => service)
        ServiceBinding.make(:app => stopped_app, :service_instance => service)
      end
    end

    subject(:request) { get "/v2/spaces/#{space.guid}/summary", {}, admin_headers }

    describe "GET /v2/spaces/:id/summary" do
      before do
        instances_reporter = CloudController::DependencyLocator.instance.instances_reporter

        allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(started_app).and_return(2)
        allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(stopped_app).and_return(0)
      end

      its(:status) { should eq 200 }

      describe "the json" do
        subject(:request) do
          get "/v2/spaces/#{space.guid}/summary", {}, admin_headers
          decoded_response
        end

        its(["guid"]) { should eq space.guid }
        its(["name"]) { should eq space.name }
        its(["apps"]) { should have(apps.count).entries }
        its(["services"]) { should have(services.count).entries }

        it "returns the correct info for the apps" do
          request["apps"].each do |app_resp|
            app = apps.find { |a| a.guid == app_resp["guid"] }.reload
            expected_running_instances = app.started? ? app.instances : 0

            expect(app_resp).to eq({
              "guid" => app.guid,
              "name" => app.name,
              "urls" => routes.map(&:fqdn),
              "routes" => [
                {
                  "guid" => routes[0].guid,
                  "host" => routes[0].host,
                  "domain" => {
                    "guid" => routes[0].domain.guid,
                    "name" => routes[0].domain.name
                  }
                }, {
                "guid" => routes[1].guid,
                "host" => routes[1].host,
                "domain" => {
                  "guid" => routes[1].domain.guid,
                  "name" => routes[1].domain.name}
              }
              ],
              "service_count" => services.count,
              "service_names" => services.map(&:name),
              "instances" => app.instances,
              "running_instances" => expected_running_instances
            }.merge(app.to_hash))
          end
        end

        it "returns the correct info for a service" do
          service_response = request["services"][0]
          service = services.find { |service| service.guid == service_response["guid"] }

          expect(service_response).to eq(
            "guid" => service.guid,
            "name" => service.name,
            "bound_app_count" => apps.count,
            "dashboard_url" => service.dashboard_url,
            "service_plan" => {
              "guid" => service.service_plan.guid,
              "name" => service.service_plan.name,
              "service" => {
                "guid" => service.service_plan.service.guid,
                "label" => service.service_plan.service.label,
                "provider" => service.service_plan.service.provider,
                "version" => service.service_plan.service.version,
              }
            }
          )
        end
      end
    end
  end
end
