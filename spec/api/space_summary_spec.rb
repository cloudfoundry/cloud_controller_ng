# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummary do
    num_services = 2
    num_started_apps = 3
    num_stopped_apps = 5
    mem_size = 128
    num_apps = num_started_apps + num_stopped_apps

    before :all do
      @space = Models::Space.make
      @route1 = Models::Route.make(:space => @space)
      @route2 = Models::Route.make(:space => @space)
      @services = []
      @apps = []

      num_services.times do
        @services << Models::ServiceInstance.make(:space => @space, :dashboard_url => "https://example.com/sso")
      end

      num_started_apps.times do |i|
        @apps << Models::App.make(
          :space => @space,
          :instances => i,
          :memory => mem_size,
          :state => "STARTED",
          :package_hash => "abc",
          :package_state => "STAGED",
        )
      end

      num_stopped_apps.times do |i|
        @apps << Models::App.make(
          :space => @space,
          :instances => i,
          :memory => mem_size,
          :state => "STOPPED",
        )
      end

      @apps.each do |app|
        app.add_route(@route1)
        app.add_route(@route2)
        @services.each do |svc|
          Models::ServiceBinding.make(:app => app, :service_instance => svc)
        end
      end
    end

    describe "GET /v2/spaces/:id/summary" do
      let(:health_response) do
        hm_resp = {}

        @apps.each do |app|
          if app.started?
            hm_resp[app.guid] = app.instances
          end
        end

        hm_resp
      end

      before do
        HealthManagerClient.should_receive(:healthy_instances).
          and_return(health_response)

        get "/v2/spaces/#{@space.guid}/summary", {}, admin_headers
      end

      it "should return 200" do
        last_response.status.should == 200
      end

      it "should return the space guid" do
        decoded_response["guid"].should == @space.guid
      end

      it "should return the space name" do
        decoded_response["name"].should == @space.name
      end

      it "should return num_apps apps" do
        decoded_response["apps"].size.should == num_apps
      end

      it "should return the correct info for the apps" do
        decoded_response["apps"].each do |app_resp|
          app = @apps.find { |a| a.guid == app_resp["guid"] }

          expected_running_instances = app.started? ? app.instances : 0

          app_resp.should == {
            "guid" => app.guid,
            "name" => app.name,
            "urls" => [@route1.fqdn, @route2.fqdn],
            "routes" => [
              {
                "guid" => @route1.guid,
                "host" => @route1.host,
                "domain" => {
                  "guid" => @route1.domain.guid,
                  "name" => @route1.domain.name
                }
              }, {
                "guid" => @route2.guid,
                "host" => @route2.host,
                "domain" => {
                  "guid" => @route2.domain.guid,
                  "name" => @route2.domain.name}
              }
            ],
            "service_count" => num_services,
            "instances" => app.instances,
            "running_instances" => expected_running_instances
          }.merge(app.to_hash)
        end
      end

      it "should return num_services services" do
        decoded_response["services"].size.should == num_services
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
          "name" => svc.name,
          "bound_app_count" => num_apps,
          "dashboard_url" => svc.dashboard_url,
          "service_plan" => {
            "guid" => svc.service_plan.guid,
            "name" => svc.service_plan.name,
            "service" => {
              "guid" => svc.service_plan.service.guid,
              "label" => svc.service_plan.service.label,
              "provider" => svc.service_plan.service.provider,
              "version" => svc.service_plan.service.version,
            }
          }
        }
      end

      context "when the health manager does not return the healthy instances for an app" do
        let(:missing_apps) do
          missing = []

          @apps.each_with_index do |app, i|
            if app.started? && i.even?
              missing << app.guid
            end
          end

          missing
        end

        let(:health_response) do
          @apps.inject({}) do |response, app|
            unless missing_apps.include?(app.guid)
              response[app.guid] = app.instances
            end

            response
          end
        end

        it "has nil for its running_instances" do
          response_apps = decoded_response["apps"]

          missing_apps.should_not be_empty
          missing_apps.each do |guid|
            responded = response_apps.find { |a| a["guid"] == guid }
            responded["running_instances"].should be_nil
          end
        end
      end
    end
  end
end
