require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyServiceGateway do
  describe "Gateway facing apis" do
    describe "POST services/v1/offerings" do
      let(:path) { "services/v1/offerings" }

      let(:auth_header) do
        Models::ServiceAuthToken.create(
          :label    => "foobar",
          :provider => "core",
          :token    => "foobar",
        )

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
        svc1.should be_valid

        svc2 = Models::Service.make(
          :label    => "foo-bar",
          :provider => "test",
          :url      => "http://localhost:56789",
        )
        svc2.should be_valid

        cfg1 = Models::ServiceInstance.make(
          :gateway_name => "foo1",
          :name => "bar1",
          :service => svc1
        )
        cfg1.should be_valid

        cfg2 = Models::ServiceInstance.make(
          :gateway_name => "foo2",
          :name => "bar2",
          :service => svc2
        )
        cfg2.should be_valid

        bdg1 = Models::ServiceBinding.make(
          :gateway_name  => "bind1",
          :service_instance  => cfg1,
          :configuration   => {},
          :binding_options => []
        )
        bdg1.should be_valid

        bdg2 = Models::ServiceBinding.make(
          :gateway_name  => "bind2",
          :service_instance  => cfg2,
          :configuration   => {},
          :binding_options => []
        )
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
end

