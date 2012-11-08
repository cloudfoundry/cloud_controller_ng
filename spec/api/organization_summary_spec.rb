# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationSummary do
    NUM_SPACES = 3
    NUM_SERVICES = 2
    NUM_PROD_APPS = 3
    NUM_FREE_APPS = 5
    PROD_MEM_SIZE = 128
    FREE_MEM_SIZE = 1024
    NUM_APPS = NUM_PROD_APPS + NUM_FREE_APPS

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before :all do
      @org = Models::Organization.make
      @spaces = []
      NUM_SPACES.times do
        @spaces << Models::Space.make(:organization => @org)
      end

      NUM_SERVICES.times do
        Models::ServiceInstance.make(:space => @spaces.first)
      end

      NUM_FREE_APPS.times do
        Models::App.make(
          :space => @spaces.first,
          :production => false,
          :instances => 1,
          :memory => FREE_MEM_SIZE,
          :state => "STARTED"
        )
      end

      NUM_PROD_APPS.times do
        Models::App.make(
          :space => @spaces.first,
          :production => true,
          :instances => 1,
          :memory => PROD_MEM_SIZE,
          :state => "STARTED"
        )
      end
    end

    describe "GET /v2/organizations/:id/summary" do
      before :all do
        get "/v2/organizations/#{@org.guid}/summary", {}, admin_headers
      end

      it "should return 200" do
        last_response.status.should == 200
      end

      it "should return the org guid" do
        decoded_response["guid"].should == @org.guid
      end

      it "should return the org name" do
        decoded_response["name"].should == @org.name
      end

      it "should return NUM_SPACES spaces" do
        decoded_response["spaces"].size.should == NUM_SPACES
      end

      it "should return the correct info for a space" do
        decoded_response["spaces"][0].should == {
          "guid" => @spaces[0].guid,
          "name" => @spaces[0].name,
          "app_count" => NUM_APPS,
          "service_count" => NUM_SERVICES,
          "mem_dev_total" => FREE_MEM_SIZE * NUM_FREE_APPS,
          "mem_prod_total" => PROD_MEM_SIZE * NUM_PROD_APPS,
        }
      end
    end
  end
end
