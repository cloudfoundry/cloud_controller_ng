# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Runtime do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/runtimes",
      :model                => Models::Runtime,
      :basic_attributes     => [:name, :description],
      :required_attributes  => [:name, :description, :internal_info],
      :unique_attributes    => :name,
      :one_to_many_collection_ids => {
        :apps  => lambda { |framework| Models::App.make }
      }
    }

    describe "GET /v2/runtimes/:guid" do
      let (:runtime) { Models::Runtime.make }
      let (:headers) do
        user = VCAP::CloudController::Models::User.make
        headers_for(user)
      end

      it "should include the version field" do
        get "/v2/runtimes/#{runtime.guid}", {}, headers
        last_response.should be_ok
        decoded_response["entity"]["version"].should == runtime.version
      end
    end

  end
end
