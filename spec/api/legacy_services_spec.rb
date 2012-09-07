require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyService do
  describe "User facing apis" do
    let(:user) { make_user_with_default_space(:admin => true) }

    describe "GET /services" do
      before do
        core_service = Models::Service.make(:provider => "core")
        core_plan = Models::ServicePlan.make(:service => core_service)
        3.times.map do |i|
          Models::ServiceInstance.make(
            :name => "core-#{i}",
            :space => user.default_space,
            :service_plan => core_plan,
          )
        end
        2.times do |i|
          Models::ServiceInstance.make(
            :name => "noncore-#{i}",
            :space => user.default_space,
          )
        end

        3.times do
          space = make_space_for_user(user)
          Models::ServiceInstance.make(:space => space)
        end

        get "/services", {}, headers_for(user)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should return an array" do
        decoded_response.should be_a_kind_of(Array)
      end

      it "should only return services for the default app space" do
        decoded_response.length.should == 5
      end

      it "should return service names" do
        names = decoded_response.map { |a| a["name"] }.sort
        names.should == [
          "core-0",
          "core-1",
          "core-2",
          "noncore-0",
          "noncore-1",
        ]
      end
    end

    describe "GET /services/v1/offerings" do
      before do
        svc = Models::Service.make(:label => "foo",
                                   :provider => "core",
                                   :version => "1.0",
                                   :url => "http://localhost:56789")

        svc_test = Models::Service.make(:label => "foo",
                                        :provider => "test",
                                        :version => "1.0",
                                        :url => "http://localhost:56789")

        [svc, svc_test].each do |s|
          Models::ServicePlan.make(:service => s, :name => "free")
          Models::ServicePlan.make(:service => s, :name => "nonfree")
        end
      end

      it "should return service offerings" do
        get "/services/v1/offerings", {}, headers_for(user)
        last_response.status.should == 200
        decoded_response["generic"]["foo"]["core"]["1.0"]["label"].should == "foo-1.0"
        decoded_response["generic"]["foo"]["core"]["1.0"]["url"].should == "http://localhost:56789"
        decoded_response["generic"]["foo"]["core"]["1.0"]["plans"].should == ["free", "nonfree"]
        decoded_response["generic"]["foo"]["core"]["1.0"]["active"].should == true
        decoded_response["generic"]["foo"]["test"]["1.0"]["label"].should == "foo-1.0"
        decoded_response["generic"]["foo"]["test"]["1.0"]["url"].should == "http://localhost:56789"
        decoded_response["generic"]["foo"]["test"]["1.0"]["plans"].should == ["free", "nonfree"]
        decoded_response["generic"]["foo"]["test"]["1.0"]["active"].should == true
      end
    end

    describe "POST /services" do
      before do
        svc = Models::Service.make(:label => "postgres", :version => "9.0")
        Models::ServicePlan.make(:service => svc, :name => LegacyService::LEGACY_PLAN_OVERIDE)
        Models::ServiceInstance.make(:space => user.default_space, :name => "duplicate")

        3.times { Models::ServiceInstance.make(:space => user.default_space) }
        @num_instances_before = Models::ServiceInstance.count
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
          post "/services", Yajl::Encoder.encode(@req), headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should add the servicew the default app space" do
          svc = user.default_space.service_instances.find(:name => "instance_name")
          svc.should_not be_nil
          Models::ServiceInstance.count.should == @num_instances_before + 1
        end
      end

      context "with an invalid vendor" do
        before do
          @req[:vendor] = "invalid"

          post "/services", Yajl::Encoder.encode(@req), headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it "should not add a service instance " do
          Models::ServiceInstance.count.should == @num_instances_before
        end

        it_behaves_like "a vcap rest error response", /service is invalid: invalid-9.0/
      end

      context "with an invalid version" do
        before do
          @req[:version] = "invalid"

          post "/services", Yajl::Encoder.encode(@req), headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it "should not add a service instance " do
          Models::ServiceInstance.count.should == @num_instances_before
        end

        it_behaves_like "a vcap rest error response", /service is invalid: postgres-invalid/
      end

      context "with a duplicate name" do
        before do
          @req[:name] = "duplicate"
          post "/services", Yajl::Encoder.encode(@req), headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it "should not add a service instance " do
          Models::ServiceInstance.count.should == @num_instances_before
        end

        it_behaves_like "a vcap rest error response", /service instance name is taken: duplicate/
      end
    end

    describe "DELETE /services/:name" do
      before do
        3.times { Models::ServiceInstance.make(:space => user.default_space) }
        @svc = Models::ServiceInstance.make(:space => user.default_space)
        @num_instances_before = Models::ServiceInstance.count
      end

      describe "with a valid name" do
        before do
          delete "/services/#{@svc.name}", {}, headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should reduce the services count by 1" do
          Models::ServiceInstance.count.should == @num_instances_before - 1
        end
      end

      describe "with an invalid name" do
        before do
          delete "/services/invalid_name", {}, headers_for(user)
        end

        it "should return not found" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", /service instance could not be found: invalid_name/
      end
    end
  end
end
