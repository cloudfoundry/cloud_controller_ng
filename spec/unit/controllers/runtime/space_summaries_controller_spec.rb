require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummariesController, type: :controller do
    let(:mem_size) { 128 }
    let(:space) { Space.make }
    let(:routes) { 2.times.map { Route.make(:space => space) } }
    let(:services) { 2.times.map { ManagedServiceInstance.make(:space => space) } }

    let!(:apps) do
      started_apps = 2.times.map do |i|
        AppFactory.make(
          space: space,
          instances: i+1,
          memory: mem_size,
          state: "STARTED",
          package_hash: "abc",
          package_state: "STAGED",
        )
      end

      stopped_apps = 2.times.map do |i|
        AppFactory.make(
          :space => space,
          :instances => i+1,
          :memory => mem_size,
          :state => "STOPPED",
        )
      end

      (started_apps + stopped_apps).map do |app|
        routes.each { |route| app.add_route(route) }
        services.each { |service| ServiceBinding.make(:app => app, :service_instance => service) }
        app
      end
    end

    subject(:request) { get "/v2/spaces/#{space.guid}/summary", {}, admin_headers }

    describe "GET /v2/spaces/:id/summary" do
      let(:health_response) { Hash[apps.select { |app| app.started? }.map { |app| [app.guid, app.instances] }] }

      before do
        health_manager_client = CloudController::DependencyLocator.instance.health_manager_client
        health_manager_client.stub(:healthy_instances) { health_response }
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

      context "when the health manager does not return the healthy instances for an app" do
        let(:missing_apps) do
          missing = []

          apps.each_with_index do |app, i|
            if app.started? && i.even?
              missing << app.guid
            end
          end

          missing
        end

        let(:health_response) do
          apps.inject({}) do |response, app|
            unless missing_apps.include?(app.guid)
              response[app.guid] = app.instances
            end

            response
          end
        end

        it "has nil for its running_instances" do
          request
          response_apps = decoded_response["apps"]

          expect(missing_apps).not_to be_empty
          missing_apps.each do |guid|
            responded = response_apps.find { |a| a["guid"] == guid }
            expect(responded["running_instances"]).to be_nil
          end
        end
      end
    end
  end
end
