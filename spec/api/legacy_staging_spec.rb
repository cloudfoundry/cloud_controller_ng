# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyStaging do
  let(:max_staging_runtime) { 120 }
  let(:cc_addr) { "1.2.3.4" }
  let(:cc_port) { 5678 }
  let(:staging_user) { "user" }
  let(:staging_password) { "password" }
  let(:app_guid) { "abc" }
  let(:staging_config) do
    {
      :max_staging_runtime => max_staging_runtime,
      :bind_address => cc_addr,
      :port => cc_port,
      :staging => {
        :auth => {
          :user => staging_user,
          :password => staging_password
        }
      }
    }
  end

  before do
    LegacyStaging.configure(staging_config)
  end

  describe "with_upload_handle" do
    it "should yield a handle with an id" do
      LegacyStaging.with_upload_handle(app_guid) do |handle|
        handle.id.should_not be_nil
      end
    end

    it "should yield a handle with the upload_path initially nil" do
      LegacyStaging.with_upload_handle(app_guid) do |handle|
        handle.upload_path.should be_nil
      end
    end

    it "should raise an error if an app guid is staged twice" do
      LegacyStaging.with_upload_handle(app_guid) do |handle|
        lambda {
          LegacyStaging.with_upload_handle(app_guid)
        }.should raise_error(Errors::StagingError, /already in progress/)
      end
    end
  end

  describe "download_app_uri" do
    it "should return a uri to our cc" do
      uri = LegacyStaging.download_app_uri(app_guid)
      uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/app/#{app_guid}"
    end
  end

  describe "upload_droplet_uri" do
    it "should return a uri to our cc" do
      uri = LegacyStaging.upload_droplet_uri(app_guid)
      uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/app/#{app_guid}"
    end
  end

  shared_examples "staging bad auth" do |verb|
    it "should return 403 for bad credentials" do
      authorize "hacker", "sw0rdf1sh"
      send(verb, "/staging/app/#{app_obj.guid}")
      last_response.status.should == 403
    end
  end

  describe "GET /staging/app/:id" do
    let(:app_obj) { Models::App.make }
    let(:app_obj_without_pkg) { Models::App.make }
    let(:app_package_path) { AppPackage.package_path(app_obj.guid) }

    before do
      config_override(staging_config)
      authorize staging_user, staging_password
      AppPackage.configure
      pkg_path = AppPackage.package_path(app_obj.guid)
      File.open(pkg_path, "w") do |f|
        f.write("A")
      end
    end

    it "should succeed for valid packages" do
      get "/staging/app/#{app_obj.guid}"
      last_response.status.should == 200
    end

    it "should return an error for non-existent apps" do
      get "/staging/app/abcd"
      last_response.status.should == 400
    end

    it "should return an error for an app without a package" do
      get "/staging/app/#{app_obj_without_pkg.guid}"
      last_response.status.should == 400
    end

    include_examples "staging bad auth", :get
  end

  describe "POST /staging/app/:id" do
    let(:app_obj) { Models::App.make }
    let(:tmpfile) { Tempfile.new("droplet.tgz") }
    let(:upload_req) do
      { :upload => { :droplet => Rack::Test::UploadedFile.new(tmpfile) } }
    end

    before do
      config_override(staging_config)
      authorize staging_user, staging_password
    end

    context "with a valid upload handle" do
      it "should rename the file and store it in handle.upload_path and delete it when the handle goes out of scope" do
        saved_path = nil
        LegacyStaging.with_upload_handle(app_obj.guid) do |handle|
          post "/staging/app/#{app_obj.guid}", upload_req
          last_response.status.should == 200
          File.exists?(handle.upload_path).should be_true
          saved_path = handle.upload_path
        end
        File.exists?(saved_path).should be_false
      end
    end

    context "with an invalid upload handle" do
      it "should return an error" do
        post "/staging/app/#{app_obj.guid}", upload_req
        last_response.status.should == 400
      end
    end

    context "with an invalid app" do
      it "should return an error" do
        LegacyStaging.with_upload_handle(app_obj.guid) do |handle|
          post "/staging/app/bad", upload_req
          last_response.status.should == 400
        end
      end
    end

    include_examples "staging bad auth", :post
  end
end
