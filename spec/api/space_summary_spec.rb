# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::SpaceSummary do
    NUM_SERVICES = 2
    NUM_PROD_APPS = 3
    NUM_FREE_APPS = 5
    PROD_MEM_SIZE = 128
    FREE_MEM_SIZE = 1024
    NUM_APPS = NUM_PROD_APPS + NUM_FREE_APPS

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

      NUM_SERVICES.times do
        @services << Models::ServiceInstance.make(:space => @space)
      end

      NUM_FREE_APPS.times do
        @apps << Models::App.make(
          :space => @space,
          :production => false,
          :instances => 1,
          :memory => FREE_MEM_SIZE,
          :state => "STARTED",
        )
      end

      NUM_PROD_APPS.times do
        @apps << Models::App.make(
          :space => @space,
          :production => true,
          :instances => 1,
          :memory => PROD_MEM_SIZE,
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
      before :all do
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

      it "should return NUM_APPS apps" do
        decoded_response["apps"].size.should == NUM_APPS
      end

      it "should return the correct info for an app" do
        app_resp = decoded_response["apps"][0]
        app = @apps.find { |a| a.guid == app_resp["guid"] }

        app_resp.should == {
          "guid" => app.guid,
          "name" => app.name,
          "urls" => [@route1.fqdn, @route2.fqdn],
          "service_count" => NUM_SERVICES,
        }.merge(app.to_hash)
      end

      it "should return NUM_SERVICES  services" do
        decoded_response["services"].size.should == NUM_SERVICES
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
          "bound_app_count" => NUM_APPS,
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
