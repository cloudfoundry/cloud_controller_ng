require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyService do

  describe "Gateway facing apis" do
    describe "POST services/v1/offerings" do
      let(:path) { "services/v1/offerings" }

      let(:auth_header) do
        Models::ServiceAuthToken.create(:label    => "foobar",
                                        :provider => "core",
                                        :token    => "foobar")

        { "HTTP_X_VCAP_SERVICE_TOKEN" => "foobar" }
      end

      let(:foo_bar_offering) do
        VCAP::Services::Api::ServiceOfferingRequest.new(
          :label => "foobar-2.2",
          :url   => "https://www.google.com",
          :description => "the foobar svc")
      end

      it "should reject requests without auth tokens" do
        post path, foo_bar_offering.encode, {}
        last_response.status.should == 403
      end

      it "should should reject posts with malformed bodies" do
        post path, Yajl::Encoder.encode(:bla => "foobar"), auth_header
        last_response.status.should == 400
      end

      it "should reject requests with missing parameters" do
        msg = { :label => "foobar-2.2",
                :description => "the foobar svc" }
        post path, Yajl::Encoder.encode(msg), auth_header
        last_response.status.should == 400
      end

      it "should reject requests with invalid parameters" do
        msg = { :label => "foobar-2.2",
                :description => "the foobar svc",
                :url => "zazzle" }
        post path, Yajl::Encoder.encode(msg), auth_header
        last_response.status.should == 400
      end

      it "should create service offerings for builtin services" do
        post path, foo_bar_offering.encode, auth_header
        last_response.status.should == 200
        svc = Models::Service.find(:label => "foobar", :provider => "core")
        svc.should_not be_nil
        svc.version.should == "2.2"
      end
    end

    describe "GET services/v1/offerings/:label(/:provider)/handles" do
      it "should return not found for unknown services" do
        get "services/v1/offerings/foo-bar/handles"
        # FIXME: should this be 404?
        last_response.status.should == 400
      end

      it "should return not found for unknown services with a provider" do
        get "services/v1/offerings/foo-bar/fooprovider/handles"
        # FIXME: should this be 404?
        last_response.status.should == 400
      end

      it "should return provisioned and bound handles" do
        svc1 = Models::Service.make(
          :label => "foo-bar",
          :provider => "core",
          :url   => "http://localhost:56789",
        )
        svc1.save
        svc1.should be_valid

        svc2 = Models::Service.make(
          :label    => "foo-bar",
          :provider => "test",
          :url      => "http://localhost:56789",
        )
        svc2.save
        svc2.should be_valid

        cfg1 = Models::ServiceInstance.make(
          :gateway_name => "foo1",
          :name => "bar1",
          :service => svc1
        )
        cfg1.save
        cfg1.should be_valid

        cfg2 = Models::ServiceInstance.make(
          :gateway_name => "foo2",
          :name => "bar2",
          :service => svc2
        )
        cfg2.save
        cfg2.should be_valid

        bdg1 = Models::ServiceBinding.make(
          :gateway_name  => "bind1",
          :service_instance  => cfg1,
          :configuration   => {},
          :credentials     => {},
          :binding_options => []
        )
        bdg1.save
        bdg1.should be_valid

        bdg2 = Models::ServiceBinding.make(
          :gateway_name  => "bind2",
          :service_instance  => cfg2,
          :configuration   => {},
          :credentials     => {},
          :binding_options => []
        )
        bdg2.save
        bdg2.should be_valid

        get "/services/v1/offerings/foo-bar/handles"
        last_response.status.should == 200
        handles = JSON.parse(last_response.body)["handles"]
        handles.size.should == 2
        handles[0]["service_id"].should == "foo1"
        handles[1]["service_id"].should == "bind1"
        get "/services/v1/offerings/foo-bar/test/handles"
        last_response.status.should == 200
        handles = JSON.parse(last_response.body)["handles"]
        handles.size.should == 2
        handles[0]["service_id"].should == "foo2"
        handles[1]["service_id"].should == "bind2"
      end
    end
  end

  describe "User facing apis" do
    let(:user) { make_user_with_default_space(:admin => true) }

    describe "GET /services" do
      before do
        @services = []
        7.times do
          @services << Models::ServiceInstance.make(:space => user.default_space)
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
        decoded_response.length.should == 7
      end

      it "should return service names" do
        names = decoded_response.map { |a| a["name"] }.sort!
        expected_names = @services.map { |a| a.name }.sort!
        names.should == expected_names
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

        it_behaves_like "a vcap rest error response", /service could not be found: invalid-9.0/
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

        it_behaves_like "a vcap rest error response", /service could not be found: postgres-invalid/
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

        it "should return bad request" do
          last_response.status.should == 400
        end

        it_behaves_like "a vcap rest error response", /service instance can not be found: invalid_name/
      end
    end
  end
end
