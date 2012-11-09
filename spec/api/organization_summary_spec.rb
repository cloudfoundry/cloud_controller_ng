# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationSummary do
    let(:num_spaces) { 2 }
    let(:num_services) { 2 }
    let(:num_prod_apps) { 3 }
    let(:num_free_apps) { 5 }
    let(:prod_mem_size) { 128 }
    let(:free_mem_size) { 1024 }
    let(:num_apps) { num_prod_apps + num_free_apps }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before :all do
      @org = Models::Organization.make
      @spaces = []
      num_spaces.times do
        @spaces << Models::Space.make(:organization => @org)
      end

      num_services.times do
        Models::ServiceInstance.make(:space => @spaces.first)
      end

      num_free_apps.times do
        Models::App.make(
          :space => @spaces.first,
          :production => false,
          :instances => 1,
          :memory => free_mem_size,
          :state => "STARTED"
        )
      end

      num_prod_apps.times do
        Models::App.make(
          :space => @spaces.first,
          :production => true,
          :instances => 1,
          :memory => prod_mem_size,
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

      it "should return num_spaces spaces" do
        decoded_response["spaces"].size.should == num_spaces
      end

      it "should return the correct info for a space" do
        decoded_response["spaces"][0].should == {
          "guid" => @spaces[0].guid,
          "name" => @spaces[0].name,
          "app_count" => num_apps,
          "service_count" => num_services,
          "mem_dev_total" => free_mem_size * num_free_apps,
          "mem_prod_total" => prod_mem_size * num_prod_apps,
        }
      end
    end
  end
end
