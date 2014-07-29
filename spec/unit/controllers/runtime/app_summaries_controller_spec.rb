require "spec_helper"

module VCAP::CloudController
  describe AppSummariesController do
    before do
      @num_services = 2
      @free_mem_size = 128

      @shared_domain = SharedDomain.make
      @shared_domain.save

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
      let(:instances_reporter) { double(:instances_reporter) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:instances_reporter).and_return(instances_reporter)
      end

      context "when the instances reporter reports instances" do
        before do
          allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).and_return(@app.instances)

          get "/v2/apps/#{@app.guid}/summary", {}, admin_headers
        end

        it "should contain the basic app attributes" do
          expect(last_response.status).to eq(200)
          expect(decoded_response["guid"]).to eq(@app.guid)
          @app.to_hash.each do |k, v|
            expect(v).to eql(decoded_response[k.to_s]), "value of field #{k} expected to eql #{v}"
          end
        end

        it "should return the app routes" do
          expect(decoded_response["routes"]).to eq([{
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
          }])
        end

        it "should contain the running instances" do
          expect(decoded_response["running_instances"]).to eq(@app.instances)
        end

        it "should contain list of both private domains and shared domains" do
          domains = @app.space.organization.private_domains
          expect(domains.count > 0).to eq(true)

          private_domains = domains.collect do |domain|
            { "guid" => domain.guid,
              "name" => domain.name,
              "owning_organization_guid" =>
                domain.owning_organization.guid
            }
          end

          shared_domains = SharedDomain.all.collect do |domain|
            { "guid" => domain.guid,
              "name" => domain.name,
            }
          end

          expect(decoded_response["available_domains"]).to match_array(private_domains + shared_domains)
        end

        it "should return the correct info for services" do
          expect(decoded_response["services"].size).to eq(@num_services)
          svc_resp = decoded_response["services"][0]
          svc = @services.find { |s| s.guid == svc_resp["guid"] }

          expect(svc_resp).to eq({
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
          })
        end
      end

      context "when the instances reporter fails" do
        class SomeInstancesException < RuntimeError
          def to_s
            "It's the end of the world as we know it."
          end
        end

        before do
          allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).and_raise(
            Errors::InstancesUnavailable.new(SomeInstancesException.new))

          get "/v2/apps/#{@app.guid}/summary", {}, admin_headers
        end

        it "returns '220001 InstancesError'" do
          expect(last_response.status).to eq(503)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response["code"]).to eq(220002)
          expect(parsed_response["description"]).to eq("Instances information unavailable: It's the end of the world as we know it.")
        end
      end
    end
  end
end
