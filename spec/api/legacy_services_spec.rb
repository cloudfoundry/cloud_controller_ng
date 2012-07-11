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
          :url   => "http://www.google.com",
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
  end

  describe "User facing apis" do
    let(:user) { make_user_with_default_app_space(:admin => true) }

    describe "GET /services" do
      before do
        @services = []
        7.times do
          @services << Models::ServiceInstance.make(:app_space => user.default_app_space)
        end

        3.times do
          app_space = make_app_space_for_user(user)
          Models::ServiceInstance.make(:app_space => app_space)
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
        names = decoded_response.map { |a| a["name"] }
        expected_names = @services.map { |a| a.name }
        names.should == expected_names
      end
    end
  end
end

