# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyStaging do
  describe "GET /staging/app/:id/" do
    let(:app_obj) { Models::App.make }
    let(:app_obj_without_pkg) { Models::App.make }
    let(:app_package_path) { AppPackage.package_path(app_obj.guid) }

    before do
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
  end
end
