# Copyright (c) 2011-2013 Uhuru Software, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::SupportedBuildpack do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/supported_buildpacks",
      :model                => Models::SupportedBuildpack,
      :basic_attributes     => [:name, :description, :buildpack],
      :required_attributes  => [:name, :description, :buildpack, :support_url],
      :unique_attributes    => :name
    }

    describe "GET /v2/supported_buildpacks/:guid" do
      let (:supported_buildpack) { Models::SupportedBuildpack.make }
      let (:headers) do
        user = VCAP::CloudController::Models::User.make
        headers_for(user)
      end

      it "should get all fields" do
        get "/v2/supported_buildpacks/#{supported_buildpack.guid}", {}, headers
        last_response.should be_ok
        decoded_response["entity"]["name"].should == supported_buildpack.name
        decoded_response["entity"]["description"].should == supported_buildpack.description
        decoded_response["entity"]["buildpack"].should == supported_buildpack.buildpack
        decoded_response["entity"]["support_url"].should == supported_buildpack.support_url
      end
    end

  end
end
