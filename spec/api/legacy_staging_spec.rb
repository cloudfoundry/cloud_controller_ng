# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyStaging do
  describe "GET /staging/app/:id/" do
    let(:app_obj) { Models::App.make }
    let(:app_package_path) { AppPackage.package_path(app_obj.guid) }

    before do
      AppPackage.configure
      AppPackage.package_path(app_obj.guid)
    end

    it "should succeed for valid packages" do
      get "/staging/app/#{app.guid}"
      last_response.status.should == 200
    end
  end
end
