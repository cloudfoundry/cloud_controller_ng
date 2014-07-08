require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationSummariesController do
    num_spaces = 2
    num_services = 2
    num_prod_apps = 3
    num_free_apps = 5
    prod_mem_size = 128
    free_mem_size = 1024
    num_apps = num_prod_apps + num_free_apps

    let(:org) { Organization.make }

    before do
      @spaces = []
      num_spaces.times do
        @spaces << Space.make(:organization => org)
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
      context "admin users" do
        before do
          get "/v2/organizations/#{org.guid}/summary", {}, admin_headers
        end

        it "return organization data" do
          expect(last_response.status).to eq(200)
          expect(decoded_response["guid"]).to eq(org.guid)
          expect(decoded_response["name"]).to eq(org.name)
          expect(decoded_response["status"]).to eq("active")
          expect(decoded_response["spaces"].size).to eq(num_spaces)
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

      context "non-admin users" do
        before do
          org.add_user member
          org.add_user non_member
          num_visible_spaces.times do
            Space.make(:organization => org).tap do |s|
              s.add_developer member
            end
          end
        end

        let(:num_visible_spaces) { 4 }

        let(:member) do
          VCAP::CloudController::User.make(admin: false)
        end

        let(:non_member) do
          VCAP::CloudController::User.make(admin: false)
        end

        context "when the user is a member of the space" do
          it "should only return spaces a user has access to" do
            get "/v2/organizations/#{org.guid}/summary", {}, json_headers(headers_for(member))
            expect(decoded_response["spaces"].size).to eq(num_visible_spaces)
          end
        end

        context "when the user is not a member of the space (but is a member of the org)" do
          it "should only return spaces a user has access to" do
            get "/v2/organizations/#{org.guid}/summary", {}, json_headers(headers_for(non_member))
            expect(decoded_response["spaces"].size).to eq(0)
          end
        end
      end
    end
  end
end
