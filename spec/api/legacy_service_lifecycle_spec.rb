# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "webmock/rspec"

module VCAP::CloudController
  describe VCAP::CloudController::LegacyServiceLifecycle do
    before :each do
      @user = make_user_with_default_space
      @mock_client = double("mock service gateway client")
      @mock_client.stub(:provision).and_return(
        VCAP::Services::Api::GatewayHandleResponse.new(
          :service_id => "lifecycle",
          :configuration => "abc",
          :credentials => { :password => "foo" }
        )
      )
      @mock_client.stub(:unprovision)
      # I miss dependency injection
      Models::ServiceInstance.any_instance.stub(:service_gateway_client)
      Models::ServiceInstance.any_instance.stub(:client).and_return(@mock_client)
      # Machinist 1.0's make_unsaved doesn't work, so
      # here's poor man's make_unsaved
      @unknown_user = Models::User.make.destroy

      service = Models::Service.make(
        :label => "jazz",
        :url => "http://12.34.56.78",
      )
      Models::ServiceInstance.make(
        :gateway_name => "lifecycle",
        :name => "bar",
        :space => make_space_for_user(@user),
        :service_plan => Models::ServicePlan.make(
          :service => service,
        ),
      )
    end

    describe "POST", "/services/v1/configurations/:gateway_name/snapshots" do
      it "should return not authorized for unknown users" do
        post "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown gateway name" do
        post "/services/v1/configurations/xxx/snapshots", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should create a snapshot job" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1",
        )
        @mock_client.stub(:create_snapshot).
          with(:service_id => "lifecycle").and_return(job)

        post "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end

      it "returns a 501 Not Implemented if upstream says so" do
        Models::ServiceInstance.any_instance.unstub(:service_gateway_client)
        Models::ServiceInstance.any_instance.unstub(:client)
        gateway_url = "http://12.34.56.78/gateway/v1/configurations/lifecycle/snapshots"
        stub_request(:post, gateway_url).to_return(
          :status => 501,
          :body => "{\"code\":1, \"description\":\"value\"}",
        )
        post "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@user)
        last_response.status.should == 501
      end
    end

    describe "GET", "/services/v1/configurations/:gateway_name/snapshots" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/snapshots", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should enumerate snapshots" do
        snapshots = VCAP::Services::Api::SnapshotList.new(
          :snapshots => [
            {:snapshot_id => "abc"},
          ],
        )
        @mock_client.stub(:enum_snapshots).
          with(:service_id => "lifecycle").and_return(snapshots)

        get "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["snapshots"].size.should == 1
        decoded_response["snapshots"][0]["snapshot_id"].should == "abc"
      end

      it "returns a 501 Not Implemented if upstream says so" do
        Models::ServiceInstance.any_instance.unstub(:service_gateway_client)
        Models::ServiceInstance.any_instance.unstub(:client)
        gateway_url = "http://12.34.56.78/gateway/v1/configurations/lifecycle/snapshots"
        stub_request(:get, gateway_url).to_return(
          :status => 501,
          :body => "{\"code\":1, \"description\":\"value\"}",
        )
        get "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@user)
        last_response.status.should == 501
      end
    end

    describe "GET", "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/snapshots/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/snapshots/yyy", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should get snapshot_details" do
        snapshot = VCAP::Services::Api::Snapshot.new(
          :snapshot_id => "abc",
          :date => "1",
          :size => 123,
          :name => "def"
        )
        @mock_client.stub(:snapshot_details).with(
            :service_id => "lifecycle",
            :snapshot_id => "abc",
          ).and_return(snapshot)

        get "/services/v1/configurations/lifecycle/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["snapshot_id"].should == "abc"
      end

      it "should handle not found error in snapshot details" do
        err = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(
          VCAP::Services::Api::ServiceErrorResponse.new(
            :code => 10000,
            :description => "not found",
          ),
        )
        @mock_client.stub(:snapshot_details).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_raise(err)

        get "/services/v1/configurations/lifecycle/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 404
      end
    end

    describe "PUT", "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        put "/services/v1/configurations/lifecycle/snapshots/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        put "/services/v1/configurations/xxx/snapshots/yyy", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should rollback a snapshot" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1",
        )

        @mock_client.stub(:rollback_snapshot).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_return(job)

        put "/services/v1/configurations/lifecycle/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end

      it "should handle not found error in rollback snapshot" do
        err = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(
            VCAP::Services::Api::ServiceErrorResponse.decode(
            {:code => 10000, :description => "not found"}.to_json
          )
        )
        @mock_client.stub(:rollback_snapshot).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_raise(err)

        put "/services/v1/configurations/lifecycle/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 404
      end
    end

    describe "DELETE", "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        delete "/services/v1/configurations/bar/snapshots/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        delete "/services/v1/configurations/xxx/snapshots/yyy", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should delete a snapshot" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1",
        )
        @mock_client.should_receive(:delete_snapshot).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_return(job)

        delete "/services/v1/configurations/lifecycle/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end

      it "should handle not found error in delete snapshot" do
        err = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(
            VCAP::Services::Api::ServiceErrorResponse.decode(
            {:code => 10000, :description => "not found"}.to_json
          )
        )
        snapshot_id = "abc"
        @mock_client.stub(:delete_snapshot).with(:service_id => "lifecycle", :snapshot_id => "abc").and_raise(err)

        delete :delete_snapshot, :id => "lifecycle", :sid => "abc"
        last_response.status.should == 404
      end
    end

    describe "GET", "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/serialized/url/snapshots/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/serialized/url/snapshots/1", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should get serialized url" do
        url = "http://api.vcap.me"
        snapshot_id = "abc"
        serialized_url = VCAP::Services::Api::SerializedURL.new(:url  => url)
        @mock_client.stub(:serialized_url).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_return(serialized_url)

        get "/services/v1/configurations/lifecycle/serialized/url/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["url"].should == url
      end
    end

    describe "POST", "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        post "/services/v1/configurations/lifecycle/serialized/url/snapshots/1", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        post "/services/v1/configurations/xxx/serialized/url/snapshots/1", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should create serialized url job" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1"
        )
        snapshot_id = "abc"
        @mock_client.stub(:create_serialized_url).with(
          :service_id => "lifecycle",
          :snapshot_id => "abc",
        ).and_return(job)

        post "/services/v1/configurations/lifecycle/serialized/url/snapshots/abc", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end
    end

    describe "PUT", "/services/v1/configurations/:gateway_name/serialized/url" do
      it "should return not authorized for unknown users" do
        put "/services/v1/configurations/lifecycle/serialized/url", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        put "/services/v1/configurations/xxx/serialized/url",
          VCAP::Services::Api::SerializedURL.new(:url  => 'http://api.vcap.me').encode,
          headers_for(@user)
        last_response.status.should == 404
      end

      it "should return bad request for malformed request" do
        put "/services/v1/configurations/xxx/serialized/url",
          %q({"data":"raw_data"}),
          headers_for(@user)
        last_response.status.should == 404
      end

      it "should create import from url job" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1"
        )
        url = "http://api.cloudfoundry.com"

        @mock_client.should_receive(:import_from_url).with(
          hash_including(
            :service_id => kind_of(String),
            :msg => kind_of(JsonMessage),
          ),
        ).and_return(job)

        put "/services/v1/configurations/lifecycle/serialized/url",
          VCAP::Services::Api::SerializedURL.new(:url => url).encode,
          headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end
    end

    describe "PUT", "/services/v1/configurations/:gateway_name/serialized/data" do
      before :each do
        config_override(
          :service_lifecycle => {
            :max_upload_size => 1,
            :upload_token    => "changeme",
            :upload_timeout  => 2,
            :serialization_data_server => ["http://sds.example.com"],
          },
        )
        @data_file = f = Tempfile.new("import_from_data")
        f.write("bar\n")
        f.close

        @mock_sds_client = mock("mock sds client")
        Models::ServiceInstance.any_instance.stub(:sds_client).with(
           "http://sds.example.com",
           "changeme",
           2,
        ).and_return(@mock_sds_client)
      end

      after :each do
        @data_file.unlink if @data_file
      end

      # disabled until upstream frees up the 501 status code ...
      xit "returns a 501 Not Implemented if upstream says so" do
        # FIXME: this should be PUT
        stub_request(:post, @sds_url).to_return(
          :status => 501,
          :body => "{\"code\":1, \"description\":\"not implemented\"}",
        )
        put "/services/v1/configurations/lifecycle/serialized/data", {
          "data_file" => Rack::Test::UploadedFile.new(@data_file.path),
        }, headers_for(@user)
        last_response.status.should == 501
      end

      it "should return not authorized for unknown users" do
        put "/services/v1/configurations/lifecycle/serialized/data", {
          "data_file" => Rack::Test::UploadedFile.new(@data_file.path),
        }, headers_for(@unknown_user)
        # FIXME: shouldn't this be 401?
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        put "/services/v1/configurations/xxx/serialized/data", {
          "data_file" => Rack::Test::UploadedFile.new(@data_file.path),
        }, headers_for(@user)
        last_response.status.should == 404
      end

      it "should create import from data job" do
        job = VCAP::Services::Api::Job.new(
          :job_id => "abc",
          :status => "queued",
          :start_time => "1",
        )

        serialized_url = VCAP::Services::Api::SerializedURL.new(
          :url => "http://api.cloudfoundry",
        )
        @mock_sds_client.should_receive(:import_from_data).with(hash_including(
          :service => "jazz",
          :service_id => "lifecycle",
        )).and_return(serialized_url)
        @mock_client.should_receive(:import_from_url).with(
          :service_id => "lifecycle",
          :msg => serialized_url,
        ).and_return(job)
        put "/services/v1/configurations/lifecycle/serialized/data", {
          "data_file" => Rack::Test::UploadedFile.new(@data_file.path),
        }, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end
    end

    describe "POST", "/services/v1/configurations/:gateway_name/serialized/uploads" do
      it "should return not authorized for unknown users" do
        post "/services/v1/configurations/lifecycle/serialized/uploads", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        post "/services/v1/configurations/xxx/serialized/uploads", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should create a upload url" do
        config_override(:external_domain => 'http://api.fake.com')
        post "/services/v1/configurations/lifecycle/serialized/uploads", {}, headers_for(@user)
        last_response.status.should == 200
        last_response.body.should == "http://api.fake.com/services/v1/configurations/lifecycle/serialized/data"
        end

      it "should create a upload url" do
        config_override(:external_domain => %w{http://api.fake.com http://api.fake2.com/})
        post "/services/v1/configurations/lifecycle/serialized/uploads", {}, headers_for(@user)
        last_response.status.should == 200
        last_response.body.should == "http://api.fake.com/services/v1/configurations/lifecycle/serialized/data"
      end
    end

    describe "GET", "/services/v1/configurations/:gateway_name/jobs/:job_id" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/jobs/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/jobs/yyy", {}, headers_for(@user)
        last_response.status.should == 404
      end

      it "should return job_info" do
        job_id = "job1"
        job = VCAP::Services::Api::Job.new(
          :job_id => job_id,
          :status => "queued",
          :start_time => "1"
        )
        @mock_client.stub(:job_info).with(
          :service_id => "lifecycle",
          :job_id => job_id,
        ).and_return(job)

        get "/services/v1/configurations/lifecycle/jobs/job1", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["job_id"].should == job_id
      end

      it "should handle not found error in get job_info" do
        err = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(
            VCAP::Services::Api::ServiceErrorResponse.decode(
            {:code => 10000, :description => "job not found"}.to_json
          )
        )
        job_id = "job1"
        @mock_client.stub(:job_info).with(
          :service_id => "lifecycle",
          :job_id => job_id,
        ).and_raise(err)

        get :job_info, :id => "lifecycle", :job_id => job_id
        last_response.status.should == 404
      end
    end
  end
end
