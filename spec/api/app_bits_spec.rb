# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppBits do
    describe "PUT /v2/app/:id/upload_bits" do
      let(:app_obj) { Models::App.make }
      let(:user) { make_user_for_space(app_obj.space) }
      let(:developer) { make_developer_for_space(app_obj.space) }
      let(:dummy_zip) { Tempfile.new("dummy_zip") }

      shared_examples "non dev app upload" do
        context "as a user" do
          it "should return 403" do
            put "/v2/apps/#{app_obj.guid}/bits", req_body, headers_for(user)
            last_response.status.should == 403
          end
        end
      end

      shared_examples "dev app upload" do |expected|
        context "as a developer" do
          extra_desc = "and set the app package_hash" if expected == 201
          it "should return #{expected} #{extra_desc}" do
            app_obj.package_hash.should be_nil
            put "/v2/apps/#{app_obj.guid}/bits", req_body, headers_for(developer)
            last_response.status.should == expected
            if expected == 201
              app_obj.refresh
              app_obj.package_hash.should_not be_nil
            end
          end
        end
      end

      context "with an empty request" do
        let(:req_body) { {} }
        include_examples "non dev app upload"
        include_examples "dev app upload", 400
      end

      context "with no application" do
        let(:req_body) do
          {
            :resources => Yajl::Encoder.encode([])
          }
        end

        include_examples "non dev app upload"
        include_examples "dev app upload", 400
      end

      context "with no resources" do
        let(:req_body) do
          {
            :application => Rack::Test::UploadedFile.new(dummy_zip)
          }
        end

        include_examples "non dev app upload"
        include_examples "dev app upload", 400
      end

      context "with a bad zipfile" do
        let(:req_body) do
          {
            :application => Rack::Test::UploadedFile.new(dummy_zip),
            :resources => Yajl::Encoder.encode([])
          }
        end

        include_examples "non dev app upload"
        include_examples "dev app upload", 400
      end

      context "with a valid zipfile" do
        let(:tmpdir) { Dir.mktmpdir }

        let(:req_body) do
          zipname = File.join(tmpdir, "file.zip")
          create_zip(zipname, 10)
          zipfile = File.new(zipname)
          {
            :application => Rack::Test::UploadedFile.new(zipfile),
            :resources => Yajl::Encoder.encode([])
          }
        end

        after do
          FileUtils.rm_rf(tmpdir)
        end

        include_examples "non dev app upload"
        include_examples "dev app upload", 201
      end
    end

    describe "GET /v2/app/:id/download" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:app_obj) { Models::App.make }
      let(:app_obj_without_pkg) { Models::App.make }
      let(:user) { make_user_for_space(app_obj.space) }
      let(:developer) { make_developer_for_space(app_obj.space) }
      let(:developer2) { make_developer_for_space(app_obj_without_pkg.space) }

      before do
        AppPackage.configure(config_override({
            :directories => { :droplets => tmpdir }
        }))

        pkg_path = AppPackage.package_path(app_obj.guid)
        File.open(pkg_path, "w") do |f|
          f.write("A")
        end
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      context "dev app download" do
        it "should return 404 for an app without a package" do
          get "/v2/apps/#{app_obj_without_pkg.guid}/download", {}, headers_for(developer2)
          last_response.status.should == 404
        end
        it "should return 200 for valid packages" do
          get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
          puts last_response.body
          last_response.status.should == 200
        end
        it "should return 404 for non-existent apps" do
          get "/v2/apps/abcd/download", {}, headers_for(developer)
          last_response.status.should == 404
        end
      end

      context "user app download" do
        it "should return 403" do
           get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(user)
           last_response.status.should == 403
        end
      end
    end
  end
end
