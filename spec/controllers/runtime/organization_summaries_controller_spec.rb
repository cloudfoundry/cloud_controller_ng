require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationSummariesController, type: :controller do
    num_spaces = 2
    num_services = 2
    num_prod_apps = 3
    num_free_apps = 5
    prod_mem_size = 128
    free_mem_size = 1024
    num_apps = num_prod_apps + num_free_apps

    before do
      @org = Organization.make
      @spaces = []
      num_spaces.times do
        @spaces << Space.make(:organization => @org)
      end

      num_services.times do
        ManagedServiceInstance.make(:space => @spaces.first)
      end

      num_free_apps.times do
        AppFactory.make(
          :space => @spaces.first,
          :production => false,
          :instances => 1,
          :memory => free_mem_size,
          :state => "STARTED",
          :package_hash => "abc",
          :package_state => "STAGED",
        )
      end

      num_prod_apps.times do
        AppFactory.make(
          :space => @spaces.first,
          :production => true,
          :instances => 1,
          :memory => prod_mem_size,
          :state => "STARTED",
          :package_hash => "abc",
          :package_state => "STAGED",
        )
      end
    end

    describe "GET /v2/organizations/:id/summary" do
      before do
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

      it "returns the org's status" do
        decoded_response["status"].should == "active"
      end

      it "should return num_spaces spaces" do
        decoded_response["spaces"].size.should == num_spaces
      end

      it "should return the correct info for all spaces" do
        expect(decoded_response["spaces"]).to include(
          "guid" => @spaces.first.guid,
          "name" => @spaces.first.name,
          "app_count" => num_apps,
          "service_count" => num_services,
          "mem_dev_total" => free_mem_size * num_free_apps,
          "mem_prod_total" => prod_mem_size * num_prod_apps,
        )
      end
    end
  end
end
