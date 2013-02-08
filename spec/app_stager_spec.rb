# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppStager do
    describe ".stage_app" do
      let(:app) { Models::App.make }
      let(:stager_client) { double(:stager_client) }
      let(:deferrable) { double(:deferrable) }
      let(:upload_handle) do
        handle = LegacyStaging::DropletUploadHandle.new(app.guid)
        handle.upload_path = Tempfile.new("tmp_droplet")
        handle
      end

      let(:incomplete_upload_handle) do
        LegacyStaging::DropletUploadHandle.new(app.guid)
      end

      before do
        configure
        VCAP::Stager::Client::EmAware.should_receive(:new).and_return stager_client
        stager_client.should_receive(:stage).and_return deferrable
        @redis = mock("mock redis")
        AppStager.configure({}, nil, @redis)
      end

      it "should stage via the staging client" do
        app.package_hash = "abc"
        app.needs_staging?.should be_true
        app.staged?.should be_false

        deferrable.should_receive(:callback).and_yield("task_log" => "log content")
        deferrable.should_receive(:errback).at_most(:once)
        LegacyStaging.should_receive(:with_upload_handle).and_yield(upload_handle)

        @redis.should_receive(:set)
        .with(StagingTaskLog.key_for_id(app.guid), "log content")
        with_em_and_thread do
          AppStager.stage_app(app)
        end

        app.needs_staging?.should be_false
        app.staged?.should be_true

        LegacyStaging.droplet_exists?(app.guid).should be_true
      end

      it "should raise a StagingError and propagate the raw description for staging client errors" do
        deferrable.should_receive(:callback).at_most(:once)
        deferrable.should_receive(:errback) do |&blk|
        blk.yield("stringy error")
        end

        with_em_and_thread do
          expect {
            AppStager.stage_app(app)
          }.to raise_error(Errors::StagingError, /stringy error/)
        end
      end

      it "should raise a StagingError and propagate the staging log for staging server errors" do
        app.package_hash = "abc"
        app.needs_staging?.should be_true
        app.staged?.should be_false

        deferrable.should_receive(:callback).and_yield("task_log" => "log content")
        deferrable.should_receive(:errback).at_most(:once)
        LegacyStaging.should_receive(:with_upload_handle).and_yield(incomplete_upload_handle)

        @redis.should_receive(:set)
        .with(StagingTaskLog.key_for_id(app.guid), "log content")

        with_em_and_thread do
          expect {
            AppStager.stage_app(app)
          }.to raise_error(Errors::StagingError, /log content/)
        end

        FileUtils.should_not_receive(:mv)

        app.needs_staging?.should be_true
        app.staged?.should be_false
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

    describe ".staging_request" do
      before(:all) do
        @app = Models::App.make
      end

      before(:all) do
        3.times do
          instance = Models::ServiceInstance.make(:space => @app.space)
          binding = Models::ServiceBinding.make(:app => @app, :service_instance => instance)
          @app.add_service_binding(binding)
        end
      end

      def store_app_package(app)
        # When Fog is in local mode it looks at the filesystem
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, "test.zip")
        create_zip(zipname, 1, 1)
        AppPackage.to_zip(app.guid, File.new(zipname), [])
        FileUtils.rm_rf(tmpdir)
      end

      it "includes app guid and download/upload uris" do
        store_app_package(@app)
        AppStager.staging_request(@app).tap do |r|
          r[:app_id].should == @app.guid
          r[:download_uri].should match /^http/
          r[:upload_uri].should match /^http/
        end
      end

      it "includes misc app properties" do
        AppStager.staging_request(@app).tap do |r|
          r[:properties][:meta].should be_kind_of(Hash)
          r[:properties][:runtime_info].should be_kind_of(Hash)
          r[:properties][:runtime_info].should have_key(:name)
          r[:properties][:framework_info].should be_kind_of(Hash)
        end
      end

      it "includes service binding properties" do
        r = AppStager.staging_request(@app)
        r[:properties][:services].count.should == 3
        r[:properties][:services].each do |s|
          s[:credentials].should be_kind_of(Hash)
          s[:options].should be_kind_of(Hash)
        end
      end

      context "when app does not have buildpack" do
        it "returns nil for buildpack" do
          @app.buildpack = nil
          r = AppStager.staging_request(@app)
          r[:properties][:buildpack].should be_nil
        end
      end

      context "when app has a buildpack" do
        it "returns url for buildpack" do
          @app.buildpack = "git://example.com/foo.git"
          res = AppStager.staging_request(@app)
          res[:properties][:buildpack].should == "git://example.com/foo.git"
        end
      end
    end

    describe ".delete_droplet" do
      before :each do
        AppStager.unstub(:delete_droplet)
      end

      let(:app) { Models::App.make }

      it "should do nothing if the droplet does not exist" do
        guid = Sham.guid
        LegacyStaging.droplet_exists?(guid).should == false
        AppStager.delete_droplet(app)
        LegacyStaging.droplet_exists?(guid).should == false
      end

      it "should delete the droplet if it exists" do
        droplet = Tempfile.new(app.guid)
        droplet.write("droplet contents")
        droplet.close
        LegacyStaging.store_droplet(app.guid, droplet.path)

        LegacyStaging.droplet_exists?(app.guid).should == true
        AppStager.delete_droplet(app)
        LegacyStaging.droplet_exists?(app.guid).should == false
      end
    end
  end
end
