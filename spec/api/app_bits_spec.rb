# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::App do
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
        it "should return #{expected}" do
          put "/v2/apps/#{app_obj.guid}/bits", req_body, headers_for(developer)
          last_response.status.should == expected
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
end
