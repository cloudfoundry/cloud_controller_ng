require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::LegacyService, :services do
    describe "User facing apis" do
      let(:user) { make_user_with_default_space(:admin => true) }

      describe "GET /services" do
        before do
          core_service = Service.make(provider: "core")
          core_plan = ServicePlan.make(service: core_service)
          3.times.map do |i|
            ManagedServiceInstance.make(
              name: "core-#{i}",
              space: user.default_space,
              service_plan: core_plan,
            )
          end
          2.times do |i|
            ManagedServiceInstance.make(
              name: "noncore-#{i}",
              space: user.default_space,
            )
          end

          3.times do
            space = make_space_for_user(user)
            ManagedServiceInstance.make(space: space)
          end

          get "/services", {}, headers_for(user)
        end

        it "should return an array" do
          expect(last_response.status).to eq(200)
          expect(decoded_response).to be_a_kind_of(Array)
        end

        it "should only return services for the default app space" do
          expect(decoded_response.length).to eq(5)
        end

        it "should return service names" do
          expect(decoded_response.map { |a| a["name"] }.sort).to eq %w[core-0 core-1 core-2 noncore-0 noncore-1]
        end
      end

      describe "GET /services/v1/offerings" do
        before do
          svc = Service.make(:label => "foo",
                                     :provider => "core",
                                     :version => "1.0",
                                     :url => "http://localhost:56789")

          svc_test = Service.make(:label => "foo",
                                          :provider => "test",
                                          :version => "1.0",
                                          :url => "http://localhost:56789")

          [svc, svc_test].each do |s|
            ServicePlan.make(:service => s, :name => "free")
            ServicePlan.make(:service => s, :name => "nonfree")
          end
        end

        it "should return service offerings" do
          get "/services/v1/offerings", {}, headers_for(user)
          expect(last_response.status).to eq(200)
          expect(decoded_response["generic"]["foo"]["core"]["1.0"]["label"]).to eq("foo-1.0")
          expect(decoded_response["generic"]["foo"]["core"]["1.0"]["url"]).to eq("http://localhost:56789")
          expect(decoded_response["generic"]["foo"]["core"]["1.0"]["plans"]).to eq(["free", "nonfree"])
          expect(decoded_response["generic"]["foo"]["core"]["1.0"]["active"]).to eq(true)
          expect(decoded_response["generic"]["foo"]["test"]["1.0"]["label"]).to eq("foo-1.0")
          expect(decoded_response["generic"]["foo"]["test"]["1.0"]["url"]).to eq("http://localhost:56789")
          expect(decoded_response["generic"]["foo"]["test"]["1.0"]["plans"]).to eq(["free", "nonfree"])
          expect(decoded_response["generic"]["foo"]["test"]["1.0"]["active"]).to eq(true)
        end
      end

      describe "POST /services" do
        before do
          svc = Service.make(:label => "postgres", :version => "9.0")
          ServicePlan.make(:service => svc, :name => LegacyService::LEGACY_PLAN_OVERIDE)
          ManagedServiceInstance.make(:space => user.default_space, :name => "duplicate")

          3.times { ManagedServiceInstance.make(:space => user.default_space) }
          @num_instances_before = ManagedServiceInstance.count
          @req = {
            :type => "database",
            :tier => "free",
            :vendor => "postgres",
            :version => "9.0",
            :name => "instance_name",
            :credentials => { "foo" => "bar" }
          }
        end

        context "with all required parameters" do
          before do
            post "/services", MultiJson.dump(@req), json_headers(headers_for(user))
          end

          it "should add the servicew the default app space" do
            expect(last_response.status).to eq(200)
            svc = user.default_space.service_instances.find(:name => "instance_name")
            expect(svc).not_to be_nil
            expect(ManagedServiceInstance.count).to eq(@num_instances_before + 1)
          end
        end

        context "with an invalid vendor" do
          it "should return bad request" do
            @req[:vendor] = "invalid"
            post "/services", MultiJson.dump(@req), json_headers(headers_for(user))

            expect(last_response.status).to eq(400)
            expect(ManagedServiceInstance.count).to eq(@num_instances_before)
            expect(decoded_response["code"]).to eq(120001)
            expect(decoded_response["description"]).to match(/service is invalid: invalid-9.0/)
          end
        end

        context "with an invalid version" do
          it "should return bad request" do
            @req[:version] = "invalid"
            post "/services", MultiJson.dump(@req), json_headers(headers_for(user))

            expect(last_response.status).to eq(400)
            expect(ManagedServiceInstance.count).to eq(@num_instances_before)
            expect(decoded_response["code"]).to eq(120001)
            expect(decoded_response["description"]).to match(/service is invalid: postgres-invalid/)
          end
        end
      end

      describe "GET /services/:name" do
        before do
          @svc = ManagedServiceInstance.make(:space => user.default_space)
        end

        describe "with a valid name" do
          it "should return the service info" do
            get "/services/#{@svc.name}", {}, headers_for(user)

            plan = @svc.service_plan
            service = plan.service

            expect(last_response.status).to eq(200)
            expect(decoded_response["name"]).to eq(@svc.name)
            expect(decoded_response["vendor"]).to eq(service.label)
            expect(decoded_response["provider"]).to eq(service.provider)
            expect(decoded_response["version"]).to eq(service.version)
            expect(decoded_response["tier"]).to eq(plan.name)
          end
        end

        describe "with an invalid name" do
          it "should return not found" do
            get "/services/invalid_name", {}, headers_for(user)

            expect(last_response.status).to eq(404)
            expect(decoded_response["code"]).to eq(60004)
            expect(decoded_response["description"]).to match(/service instance could not be found: invalid_name/)
          end
        end
      end

      describe "DELETE /services/:name" do
        before do
          3.times { ManagedServiceInstance.make(:space => user.default_space) }
          @svc = ManagedServiceInstance.make(:space => user.default_space)
          @num_instances_before = ManagedServiceInstance.count
        end

        describe "with a valid name" do
          it "should reduce the services count by 1" do
            delete "/services/#{@svc.name}", {}, headers_for(user)

            expect(last_response.status).to eq(200)
            expect(ManagedServiceInstance.count).to eq(@num_instances_before - 1)
          end
        end

        describe "with an invalid name" do
          it "should return not found" do
            delete "/services/invalid_name", {}, headers_for(user)

            expect(last_response.status).to eq(404)
            expect(decoded_response["code"]).to eq(60004)
            expect(decoded_response["description"]).to match(/service instance could not be found: invalid_name/)
          end
        end
      end
    end
  end
end
