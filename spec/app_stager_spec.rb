# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppStager do
    describe "staging_request" do
      let(:app_obj) { Models::App.make }
      NUM_INSTANCES = 3

      before do
        configure
        NUM_INSTANCES.times do
          instance = Models::ServiceInstance.make(:space => app_obj.space)
          binding = Models::ServiceBinding.make(:app => app_obj,
                                                :service_instance => instance)
          app_obj.add_service_binding(binding)
        end

      end

      it "should return a serialized staging request" do
        # This should be moved to a helper function
        guid = app_obj.guid
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, "test.zip")
        create_zip(zipname, 10, 1024)
        AppPackage.to_zip(guid, File.new(zipname), [])
        FileUtils.rm_rf(tmpdir)

        res = AppStager.send(:staging_request, app_obj)
        res.should be_kind_of(Hash)
        res[:app_id].should == app_obj.guid
        res[:download_uri].should be_kind_of(String)
        res[:upload_uri].should be_kind_of(String)
        res[:properties][:meta].should be_kind_of(Hash)
        res[:properties][:runtime_info].should be_kind_of(Hash)
        res[:properties][:runtime_info].should have_key(:name)
        res[:properties][:framework_info].should be_kind_of(Hash)
        res[:properties][:buildpack].should be_nil
        res[:properties][:services].count.should == NUM_INSTANCES
        res[:properties][:services].each do |svc|
          svc[:credentials].should be_kind_of(Hash)
          svc[:options].should be_kind_of(Hash)
        end
      end

      context "when the application has a buildpack" do
        before do
          app_obj.buildpack = "git://example.com/foo.git"
        end

        it "contains the buildpack in the staging request" do
          res = AppStager.send(:staging_request, app_obj)
          res.should be_kind_of(Hash)
          res[:properties][:buildpack].should == "git://example.com/foo.git"
        end
      end
    end

    describe ".stage_app" do
      let(:app_obj) { Models::App.make }
      let(:stager_client) { double(:stager_client) }
      let(:deferrable) { double(:deferrable) }
      let(:upload_handle) do
        handle = LegacyStaging::DropletUploadHandle.new(app_obj.guid)
        handle.upload_path = Tempfile.new("tmp_droplet")
        handle
      end

      let(:incomplete_upload_handle) do
        LegacyStaging::DropletUploadHandle.new(app_obj.guid)
      end

      before do
        configure
        VCAP::Stager::Client::EmAware.should_receive(:new).and_return stager_client
        stager_client.should_receive(:stage).and_return deferrable
        @redis = mock("mock redis")
        AppStager.configure({}, nil, @redis)
      end

      it "should stage via the staging client" do
        app_obj.package_hash = "abc"
        app_obj.needs_staging?.should be_true
        app_obj.staged?.should be_false

        deferrable.should_receive(:callback).and_yield("task_log" => "log content")
        deferrable.should_receive(:errback).at_most(:once)
        LegacyStaging.should_receive(:with_upload_handle).and_yield(upload_handle)

        @redis.should_receive(:set)
        .with(StagingTaskLog.key_for_id(app_obj.guid), "log content")
        with_em_and_thread do
          AppStager.stage_app(app_obj)
        end

        app_obj.needs_staging?.should be_false
        app_obj.staged?.should be_true

        LegacyStaging.droplet_exists?(app_obj.guid).should be_true
      end

      it "should raise a StagingError and propagate the raw description for staging client errors" do
        deferrable.should_receive(:callback).at_most(:once)
        deferrable.should_receive(:errback) do |&blk|
        blk.yield("stringy error")
        end

        with_em_and_thread do
          expect {
            AppStager.stage_app(app_obj)
          }.to raise_error(Errors::StagingError, /stringy error/)
        end
      end

      it "should raise a StagingError and propagate the staging log for staging server errors" do
        app_obj.package_hash = "abc"
        app_obj.needs_staging?.should be_true
        app_obj.staged?.should be_false

        deferrable.should_receive(:callback).and_yield("task_log" => "log content")
        deferrable.should_receive(:errback).at_most(:once)
        LegacyStaging.should_receive(:with_upload_handle).and_yield(incomplete_upload_handle)

        @redis.should_receive(:set)
        .with(StagingTaskLog.key_for_id(app_obj.guid), "log content")

        with_em_and_thread do
          expect {
            AppStager.stage_app(app_obj)
          }.to raise_error(Errors::StagingError, /log content/)
        end

        FileUtils.should_not_receive(:mv)

        app_obj.needs_staging?.should be_true
        app_obj.staged?.should be_false
      end
    end

    describe ".stage_app_async (blocks until url is returned)" do
      subject { described_class }
      let(:app) { Models::App.make }

      it "sends staging.async request" do
        staging_request = {:staging => "request"}

        described_class
          .should_receive(:staging_request)
          .with(app)
          .and_return(staging_request)

        described_class.message_bus.should_receive(:request).with(
          "staging.async",
          JSON.dump(staging_request),
          {:expected => 1}
        ).and_return([])

        subject.stage_app_async(app) rescue nil
      end

      context "when staging successfully starts" do
        let(:response) do
          JSON.dump(
            :task_id => "task-id",
            :streaming_log_url => "http://stream-log-url")
        end

        it "returns url to stream staging log" do
          described_class.message_bus
            .should_receive(:request)
            .and_return([response])

          subject.stage_app_async(app).tap do |r|
            r.task_id.should == "task-id"
            r.streaming_log_url.should == "http://stream-log-url"
          end
        end
      end

      context "when dea indicates that staging failed" do
        let(:response) do
          JSON.dump(:error => "some-error")
        end

        it "raises staging error" do
          described_class.message_bus
            .should_receive(:request)
            .and_return([response])

          expect {
            subject.stage_app_async(app)
          }.to raise_error(described_class::AsyncError)
        end
      end

      context "when request timed out" do
        it "raises staging error" do
          described_class.message_bus.should_receive(:request).and_return([])
          expect {
            subject.stage_app_async(app)
          }.to raise_error(described_class::AsyncError)
        end
      end
    end

    describe ".delete_droplet" do
      before :each do
        AppStager.unstub(:delete_droplet)
      end

      let(:app_obj) { Models::App.make }

      it "should do nothing if the droplet does not exist" do
        guid = Sham.guid
        LegacyStaging.droplet_exists?(guid).should == false
        AppStager.delete_droplet(app_obj)
        LegacyStaging.droplet_exists?(guid).should == false
      end

      it "should delete the droplet if it exists" do
        droplet = Tempfile.new(app_obj.guid)
        droplet.write("droplet contents")
        droplet.close
        LegacyStaging.store_droplet(app_obj.guid, droplet.path)

        LegacyStaging.droplet_exists?(app_obj.guid).should == true
        AppStager.delete_droplet(app_obj)
        LegacyStaging.droplet_exists?(app_obj.guid).should == false
      end
    end
  end
end
