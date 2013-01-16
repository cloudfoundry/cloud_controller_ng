# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummary do
    let(:num_services) { 2 }
    let(:num_started_apps) { 3 }
    let(:num_stopped_apps) { 5 }
    let(:mem_size) { 128 }
    let(:num_apps) { num_started_apps + num_stopped_apps }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before :all do
      @space = Models::Space.make
      @route1 = Models::Route.make(:space => @space)
      @route2 = Models::Route.make(:space => @space)
      @services = []
      @apps = []

      num_services.times do
        @services << Models::ServiceInstance.make(:space => @space)
      end

      num_started_apps.times do |i|
        @apps << Models::App.make(
          :space => @space,
          :instances => i,
          :memory => mem_size,
          :state => "STARTED",
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
      before do
        hm_resp = {}
        @apps.each do |app|
          if app.started?
            hm_resp[app.guid] = app.instances
          end
        end

        HealthManagerClient.should_receive(:healthy_instances).and_return(hm_resp)
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
            "routes" => [{
              "guid" => @route1.guid,
              "host" => nil,
              "domain" => {
                "guid" => @route1.domain.guid,
                "name" => @route1.domain.name
              }
            }, {
              "guid" => @route2.guid,
              "host" => nil,
              "domain" => {
                "guid" => @route2.domain.guid,
                "name" => @route2.domain.name}
            }],
            "service_count" => num_services,
            "instances" => app.instances,
            "running_instances" => expected_running_instances,
            "framework_name" => app.framework.name,
            "runtime_name" => app.runtime.name,
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
    end
  end
end
