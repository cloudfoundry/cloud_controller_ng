# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

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
      res = AppStager.send(:staging_request, app_obj)
      res.should be_kind_of(Hash)
      res[:app_id].should == app_obj.guid
      res[:download_uri].should be_kind_of(String)
      res[:upload_uri].should be_kind_of(String)
      res[:properties][:services].count.should == NUM_INSTANCES
      res[:properties][:services].each do |svc|
        svc[:credentials].should be_kind_of(Hash)
        svc[:options].should be_kind_of(Hash)
      end
    end
  end

  describe "stage_app" do
    let(:app_obj) { Models::App.make }
    let(:stager_client) { double(:stager_client) }
    let(:deferrable) { double(:deferrable) }
    let(:upload_handle) do
      handle = LegacyStaging::DropletUploadHandle.new(app_obj.guid)
      handle.upload_path = Tempfile.new("tmp_droplet")
      handle
    end

    before do
      configure
      VCAP::Stager::Client::EmAware.should_receive(:new).and_return stager_client
      stager_client.should_receive(:stage).and_return deferrable
      @redis = mock("mock redis")
      AppStager.configure({}, @redis)
    end

    it "should stage via the staging client" do
      app_obj.package_hash = "abc"
      app_obj.needs_staging?.should be_true
      app_obj.staged?.should be_false

      deferrable.should_receive(:callback).and_yield(:task_log => "log content")
      deferrable.should_receive(:errback).at_most(:once)
      LegacyStaging.should_receive(:with_upload_handle).and_yield(upload_handle)

      @redis.should_receive(:set)
        .with(StagingTaskLog.key_for_id(app_obj.guid), "log content")
      with_em_and_thread do
        AppStager.stage_app(app_obj)
      end

      app_obj.needs_staging?.should be_false
      app_obj.staged?.should be_true

      File.exists?(AppStager.droplet_path(app_obj)).should be_true
    end

    it "should raise a StagingError and propagate the raw description" do
      deferrable.should_receive(:callback).at_most(:once)
      deferrable.should_receive(:errback).and_yield("stringy error")

      with_em_and_thread do
        lambda {
          AppStager.stage_app(app_obj)
        }.should raise_error(Errors::StagingError, /stringy error/)
      end
    end
  end
end
