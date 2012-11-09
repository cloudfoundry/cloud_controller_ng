# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummary do
    let(:num_services) { 2 }
    let(:num_prod_apps) { 3 }
    let(:num_free_apps) { 5 }
    let(:prod_mem_size) { 128 }
    let(:free_mem_size) { 1024 }
    let(:num_apps) { num_prod_apps + num_free_apps }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before(:all) do
      @space = Models::Space.make
      @route1 = Models::Route.make(:space => @space)
      @route2 = Models::Route.make(:space => @space)
      @services = []
      @apps = []

      num_services.times do
        @services << Models::ServiceInstance.make(:space => @space)
      end

      num_free_apps.times do |i|
        @apps << Models::App.make(
          :space => @space,
          :production => false,
          :instances => i,
          :memory => free_mem_size,
          :state => "STARTED",
        )
      end

      num_prod_apps.times do |i|
        @apps << Models::App.make(
          :space => @space,
          :production => true,
          :instances => i,
          :memory => prod_mem_size,
          :state => "STARTED",
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
        @apps.each { |app| hm_resp[app.guid] = app.instances }
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

      it "should return the correct info for an app" do
        app_resp = decoded_response["apps"][0]
        app = @apps.find { |a| a.guid == app_resp["guid"] }

        app_resp.should == {
          "guid" => app.guid,
          "name" => app.name,
          "urls" => [@route1.fqdn, @route2.fqdn],
          "service_count" => num_services,
          "instances" => 1,
          "running_instances" => app.instances,
          "framework_name" => app.framework.name,
          "runtime_name" => app.runtime.name,
        }.merge(app.to_hash)
      end

      it "should return num_services  services" do
        decoded_response["services"].size.should == num_services
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
          "bound_app_count" => num_apps,
          "service_guid" => svc.service_plan.service.guid,
          "label" => svc.service_plan.service.label,
          "provider" => svc.service_plan.service.provider,
          "version" => svc.service_plan.service.version,
          "plan_guid" => svc.service_plan.guid,
          "plan_name" => svc.service_plan.name,
        }
      end
    end
  end
end
