# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppSummary do
    let(:num_services) { 2 }
    let(:free_mem_size) { 128 }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before :all do
      @space = Models::Space.make
      @route1 = Models::Route.make(:space => @space)
      @route2 = Models::Route.make(:space => @space)
      @services = []

      @app = Models::App.make(
        :space => @space,
        :production => false,
        :instances => 1,
        :memory => free_mem_size,
        :state => "STARTED",
      )

      num_services.times do
        instance = Models::ServiceInstance.make(:space => @space)
        @services << instance
        Models::ServiceBinding.make(:app => @app, :service_instance => instance)
      end

      @app.add_route(@route1)
      @app.add_route(@route2)
    end

    describe "GET /v2/apps/:id/summary" do
      before :all do
        get "/v2/apps/#{@app.guid}/summary", {}, admin_headers
      end

      it "should return 200" do
        last_response.status.should == 200
      end

      it "should return the app guid" do
        decoded_response["guid"].should == @app.guid
      end

      it "should return the app name" do
        decoded_response["name"].should == @app.name
      end

      it "should return the app urls" do
        decoded_response["urls"].should == [@route1.fqdn, @route2.fqdn]
      end

      it "should return the app framework" do
        decoded_response["framework"]["guid"].should == @app.framework.guid
        decoded_response["framework"]["name"].should == @app.framework.name
      end

      it "should return the app runtime" do
        decoded_response["runtime"]["guid"].should == @app.runtime.guid
        decoded_response["runtime"]["name"].should == @app.runtime.name
      end

      it "should return num_services services" do
        decoded_response["services"].size.should == num_services
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
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
