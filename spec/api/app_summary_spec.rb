# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppSummary do
    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before(:all) do
      @num_services = 2
      @free_mem_size = 128

      @system_domain = Models::Domain.new(:name => Sham.domain,
        :owning_organization => nil)
      @system_domain.save(:validate => false)

      @space = Models::Space.make
      @route1 = Models::Route.make(:space => @space)
      @route2 = Models::Route.make(:space => @space)
      @services = []

      @app = Models::App.make(
        :space => @space,
        :production => false,
        :instances => 1,
        :memory => @free_mem_size,
        :state => "STARTED",
      )

      @num_services.times do
        instance = Models::ServiceInstance.make(:space => @space)
        @services << instance
        Models::ServiceBinding.make(:app => @app, :service_instance => instance)
      end

      @app.add_route(@route1)
      @app.add_route(@route2)
    end

    after(:all) do
      @system_domain.destroy
    end

    describe "GET /v2/apps/:id/summary" do
      before do
        HealthManagerClient.should_receive(:healthy_instances).
          and_return(@app.instances)
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

      it "should return the app routes" do
        decoded_response["routes"].should == [{
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
        }]
      end

      it "should return the app framework" do
        decoded_response["framework"]["guid"].should == @app.framework.guid
        decoded_response["framework"]["name"].should == @app.framework.name
      end

      it "should return the app runtime" do
        decoded_response["runtime"]["guid"].should == @app.runtime.guid
        decoded_response["runtime"]["name"].should == @app.runtime.name
      end

      it "should contain the running instances" do
        decoded_response["running_instances"].should == @app.instances
      end

      it "should contain the basic app attributes" do
        @app.to_hash.each do |k, v|
          decoded_response[k.to_s].should == v
        end
      end

      it "should contain list of available domains" do
        _, domain1, domain2 = @app.space.domains
        decoded_response["available_domains"].should =~ [
          {"guid" => domain1.guid, "name" => domain1.name, "owning_organization_guid" => domain1.owning_organization.guid},
          {"guid" => domain2.guid, "name" => domain2.name, "owning_organization_guid" => domain2.owning_organization.guid},
          {"guid" => @system_domain.guid, "name" => @system_domain.name, "owning_organization_guid" => nil}
        ]
      end

      it "should return num_services services" do
        decoded_response["services"].size.should == @num_services
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
          "name" => svc.name,
          "bound_app_count" => 1,
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
