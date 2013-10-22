require "spec_helper"

module VCAP::CloudController
  describe AppSummariesController, type: :controller do
    before do
      @num_services = 2
      @free_mem_size = 128

      @system_domain = Domain.new(
          :name => Sham.domain,
          :owning_organization => nil)
      @system_domain.save(:validate => false)

      @space = Space.make
      @route1 = Route.make(:space => @space)
      @route2 = Route.make(:space => @space)
      @services = []

      @app = AppFactory.make(
        :space => @space,
        :production => false,
        :instances => 1,
        :memory => @free_mem_size,
        :state => "STARTED",
        :package_hash => "abc",
        :package_state => "STAGED"
      )

      @num_services.times do
        instance = ManagedServiceInstance.make(:space => @space)
        @services << instance
        ServiceBinding.make(:app => @app, :service_instance => instance)
      end

      @app.add_route(@route1)
      @app.add_route(@route2)
    end

    describe "GET /v2/apps/:id/summary" do
      before do
        health_manager_client = CloudController::DependencyLocator.instance.health_manager_client
        health_manager_client.should_receive(:healthy_instances).and_return(@app.instances)
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
        }]
      end

      it "should contain the running instances" do
        decoded_response["running_instances"].should == @app.instances
      end

      it "should contain the basic app attributes" do
        @app.to_hash.each do |k, v|
          v.should eql(decoded_response[k.to_s]), "value of field #{k} expected to eql #{v}"
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

      it "should return correct number of services" do
        decoded_response["services"].size.should == @num_services
      end

      it "should return the correct info for a service" do
        svc_resp = decoded_response["services"][0]
        svc = @services.find { |s| s.guid == svc_resp["guid"] }

        svc_resp.should == {
          "guid" => svc.guid,
          "name" => svc.name,
          "bound_app_count" => 1,
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
    end
  end
end
