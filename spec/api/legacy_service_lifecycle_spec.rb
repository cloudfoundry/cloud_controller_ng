# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe LegacyServiceLifecycle do
    before :each do
      @user = make_user_with_default_space
      @mock_client = double("mock service gateway client")
      # I miss dependency injection
      Models::ServiceInstance.any_instance.stub(:service_gateway_client).and_return(@mock_client)
      # Machinist 1.0's make_unsaved doesn't work, so
      # here's poor man's make_unsaved
      @unknown_user = Models::User.make.destroy

      service_instance = Models::ServiceInstance.make(
        :gateway_name => "lifecycle",
        :name => "bar",
        :space => @user.default_space,
      )
      Models::ServiceAuthToken.create(
        :service => service_instance.service,
        :token => "meow",
      )
    end

    describe "#lifecycle_extension" # do
    #   it 'should return not implemented error when lifecycle is disabled' do
    #     begin
    #       origin = AppConfig.delete :service_lifecycle
    #       %w(create_snapshot enum_snapshots import_from_url import_from_data).each do |api|
    #         post api.to_sym, :id => 'xxx'
    #         response.status.should == 501
    #         resp = Yajl::Parser.parse(response.body)
    #         resp['description'].include?("not implemented").should == true
    #       end

    #       %w(snapshot_details rollback_snapshot delete_snapshot serialized_url create_serialized_url ).each do |api|
    #         post api.to_sym, :id => 'xxx', :sid => '1'
    #         response.status.should == 501
    #         resp = Yajl::Parser.parse(response.body)
    #         resp['description'].include?("not implemented").should == true
    #       end

    #       get :job_info, :id => 'xxx', :job_id => '1'
    #       response.status.should == 501
    #       resp = Yajl::Parser.parse(response.body)
    #       resp['description'].include?("not implemented").should == true
    #     ensure
    #       AppConfig[:service_lifecycle] = origin
    #     end
    #   end
    # end

    describe "POST", "/services/v1/configurations/:gateway_name/snapshots" do
      it "should return not authorized for unknown users" do
        post "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown gateway name" do
        post "/services/v1/configurations/xxx/snapshots", {}, headers_for(@user)
        # FIXME: should be 404
        last_response.status.should == 400
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
    end

    describe "GET", "/services/v1/configurations/:gateway_name/snapshots" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/snapshots", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/snapshots", {}, headers_for(@user)
        # FIXME: should be 404
        last_response.status.should == 400
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
    end

    describe "GET", "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id" do
      it "should return not authorized for unknown users" do
        get "/services/v1/configurations/lifecycle/snapshots/yyy", {}, headers_for(@unknown_user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get "/services/v1/configurations/xxx/snapshots/yyy", {}, headers_for(@user)
        # FIXME: should be 404
        last_response.status.should == 400
      end

      it "should get snapshot_details" do
        snapshot = VCAP::Services::Api::Snapshot.new(
          :snapshot_id => "abc",
          :date => "1",
          :size => 123
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
        # FIXME should be 404
        last_response.status.should == 400
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
        # FIXME should be 404
        last_response.status.should == 400
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
        get "/services/v1/configurations/lifecycle/serialized/url/snapshots/yyy", {}, headers_for(@user)
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get :serialized_url, :id => 'xxx', :sid => '1'
        last_response.status.should == 404
      end

      it "should get serialized url" do
        url = "http://api.vcap.me"
        snapshot_id = "abc"
        serialized_url = VCAP::Services::Api::SerializedURL.new(:url  => url)
        @mock_client.stub(:serialized_url).with(:service_id => "lifecycle", :snapshot_id => "abc" ).returns serialized_url

        get :serialized_url, :id => "lifecycle", :sid => "abc"
        last_response.status.should == 200
        decoded_response["url"].should == url
      end
    end

    describe "#create_serialized_url" do
      before :each do
        cfg = ServiceConfig.new(:name => 'lifecycle', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg
      end

      it "should return not authorized for unknown users" do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        post :create_serialized_url, :id => 'xxx', :sid => '1'
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        post :create_serialized_url, :id => 'xxx', :sid => '1'
        last_response.status.should == 404
      end

      it "should create serialized url job" do
        job = VCAP::Services::Api::Job.decode(
          {
          :job_id => "abc",
          :status => "queued",
          :start_time => "1"
          }.to_json
        )
        snapshot_id = "abc"
        @mock_client.stub(:create_serialized_url).with(:service_id => "lifecycle", :snapshot_id => "abc").returns job

        post :create_serialized_url, :id => "lifecycle", :sid => "abc"
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end
    end

    describe "#import_from_url" do
      before :each do
        cfg = ServiceConfig.new(:name => 'lifecycle', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg
      end

      it "should return not authorized for unknown users" do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        put :import_from_url, :id => 'xxx'
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        put_msg :import_from_url, :id => 'xxx' do
          VCAP::Services::Api::SerializedURL.new(:url  => 'http://api.vcap.me')
        end
        last_response.status.should == 404
      end

      it "should return bad request for malformed request" do
        put_msg :import_from_url, :id => 'xxx' do
          # supply wrong request
          VCAP::Services::Api::SerializedData.new(:data => "raw_data")
        end
        last_response.status.should == 400
      end

      it "should create import from url job" do
        job = VCAP::Services::Api::Job.decode(
          {
          :job_id => "abc",
          :status => "queued",
          :start_time => "1"
          }.to_json
        )
        url = "http://api.cloudfoundry.com"

        req = VCAP::Services::Api::SerializedURL.new(:url => url)
        @mock_client.stub(:import_from_url).with(anything).returns job

        put_msg :import_from_url, :id => "lifecycle" do
          req
        end
        last_response.status.should == 200
        decoded_response["job_id"].should == "abc"
      end
    end

    describe "#import_from_data" do
      before :each do
        cfg = ServiceConfig.new(:name => 'lifecycle', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg
      end

      it "should return not authorized for unknown users" do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        put :import_from_data, :id => 'xxx'
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        begin
          tmp_file = Tempfile.new('foo_import_from_data')
          put :import_from_data, :id => 'xxx', :data_file => tmp_file
          last_response.status.should == 404
        ensure
          FileUtils.rm_rf(tmp_file.path) if tmp_file
        end
      end

      it "should create import from data job" do
        job = VCAP::Services::Api::Job.decode(
          {
          :job_id => "abc",
          :status => "queued",
          :start_time => "1"
          }.to_json
        )

        url = "http://api.cloudfoundry"
        @mock_client.stub(:import_from_url).with(anything).returns job
        VCAP::Services::Api::SDSClient.any_instance.stubs(:import_from_data).with(anything).returns VCAP::Services::Api::SerializedURL.new(:url => url)
        begin
          tmp_file = Tempfile.new('foo_import_from_data')
          put :import_from_data, :id => "lifecycle", :data_file => tmp_file
          last_response.status.should == 200
          decoded_response["job_id"].should == "abc"
        ensure
          FileUtils.rm_rf(tmp_file.path) if tmp_file
        end
      end
    end

    describe "#job_info" do
      before :each do
        cfg = ServiceConfig.new(:name => 'lifecycle', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg
      end

      it "should return not authorized for unknown users" do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        get :job_info, :id => 'xxx', :job_id => 'yyy'
        last_response.status.should == 403
      end

      it "should return not found for unknown ids" do
        get :job_info, :id => 'xxx' , :job_id => 'yyy'
        last_response.status.should == 404
      end

      it "should return job_info" do
        job_id = "job1"
        job = VCAP::Services::Api::Job.decode(
          {
          :job_id => job_id,
          :status => "queued",
          :start_time => "1"
          }.to_json
        )
        @mock_client.stub(:job_info).with(:service_id => "lifecycle", :job_id => job_id).returns job

        get :job_info, :id => "lifecycle", :job_id => job_id
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
        @mock_client.stub(:job_info).with(:service_id => "lifecycle", :job_id => job_id).raises err

        get :job_info, :id => "lifecycle", :job_id => job_id
        last_response.status.should == 404
      end
    end
  end
end
