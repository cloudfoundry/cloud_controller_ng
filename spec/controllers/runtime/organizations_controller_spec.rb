require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationsController, type: :controller do
    let(:org) { Organization.make }
    include_examples "uaa authenticated api", path: "/v2/organizations"
    include_examples "querying objects", path: "/v2/organizations", model: Organization, queryable_attributes: %w(name status)
    include_examples "enumerating objects", path: "/v2/organizations", model: Organization
    include_examples "reading a valid object", path: "/v2/organizations", model: Organization, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/organizations"
    include_examples "creating and updating", path: "/v2/organizations", model: Organization, required_attributes: %w(name), unique_attributes: %w(name)
    include_examples "deleting a valid object", path: "/v2/organizations", model: Organization,
      one_to_many_collection_ids: {
        :spaces => lambda { |org| Space.make(:organization => org) },
        :service_instances => lambda { |org|
          space = Space.make(:organization => org)
          ManagedServiceInstance.make(:space => space)
        },
        :apps => lambda { |org|
          space = Space.make(:organization => org)
          AppFactory.make(:space => space)
        },
        :private_domains => lambda { |org|
          PrivateDomain.make(:owning_organization => org)
        }
      }
    include_examples "collection operations", path: "/v2/organizations", model: Organization,
      one_to_many_collection_ids: {
        spaces: lambda { |org| Space.make(organization: org) },
        private_domains: lambda { |org| PrivateDomain.make(owning_organization: org) },
      },
      one_to_many_collection_ids_without_url: {
        service_instances: lambda { |org| ManagedServiceInstance.make(space: Space.make(organization: org)) },
        apps: lambda { |org| AppFactory.make(space: Space.make(organization: org)) },
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {
        users: lambda { |org| User.make },
        managers: lambda { |org| User.make },
        billing_managers: lambda { |org| User.make }
      }

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @org_a
        @obj_b = @org_b
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end
      end
    end

    describe "billing" do
      let(:org_admin_headers) do
        user = User.make
        org.add_user(user)
        org.add_manager(user)
        headers_for(user)
      end

      it "should export the billing_enabled flag" do
        org.billing_enabled = true
        org.save(:validate => false)
        get "/v2/organizations/#{org.guid}", {}, admin_headers
        last_response.status.should == 200
        decoded_response["entity"]["billing_enabled"].should == true
      end

      describe "cf admins" do
        it "should be allowed to set billing_enabled flag to true" do
          org.billing_enabled.should == false
          req = Yajl::Encoder.encode(:billing_enabled => true)
          put "/v2/organizations/#{org.guid}", req, json_headers(admin_headers)
          last_response.status.should == 201
          decoded_response["entity"]["billing_enabled"].should == true
          org.refresh
          org.billing_enabled.should == true
        end
      end

      describe "org admins" do
        it "should not be allowed to set billing_enabled flag to true" do
          org.billing_enabled.should == false
          req = Yajl::Encoder.encode(:billing_enabled => true)
          put "/v2/organizations/#{org.guid}", req, json_headers(org_admin_headers)
          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == false
        end

        it "should not be allowed to set billing_enabled flag to false" do
          org.billing_enabled = true
          org.save(:validate => false)
          req = Yajl::Encoder.encode(:billing_enabled => false)
          put "/v2/organizations/#{org.guid}", req, json_headers(org_admin_headers)
          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == true
        end
      end
    end

    describe 'GET /v2/organizations/:guid/domains' do
      let(:organization) { Organization.make }
      let(:manager) { make_manager_for_org(organization) }

      before do
        @private_domain = PrivateDomain.make(owning_organization: organization)
        @shared_domain = SharedDomain.make
      end

      it "should return the private domains associated with the organization and all shared domains" do
        get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(manager)
        expect(last_response.status).to eq(200)
        resources = decoded_response.fetch("resources")
        expect(resources).to have(2).items
        guids = resources.map { |x| x["metadata"]["guid"] }
        expect(guids).to match_array([@shared_domain.guid, @private_domain.guid])
      end
    end

    describe "quota definition" do
      let(:org_admin_headers) do
        user = User.make
        org.add_user(user)
        org.add_manager(user)
        headers_for(user)
      end

      let(:quota_definition) do
        QuotaDefinition.make
      end

      let(:update_request) do
        Yajl::Encoder.encode(:quota_definition_guid => quota_definition.guid)
      end

      describe "cf admins" do
        it "should be allowed to set the quota definition" do
          put "/v2/organizations/#{org.guid}", update_request, json_headers(admin_headers)
          last_response.status.should == 201
          org.refresh
          org.quota_definition.should == quota_definition
        end
      end

      describe "org admins" do
        it "should not be allowed to set the quota definition" do
          orig_quota_definition = org.quota_definition
          put "/v2/organizations/#{org.guid}", update_request, json_headers(org_admin_headers)
          last_response.status.should == 403
          org.refresh
          org.quota_definition.should == orig_quota_definition
        end
      end
    end

    describe "app_events associations" do
      it "does not return app_events with inline-relations-depth=0" do
        org = Organization.make
        get "/v2/organizations/#{org.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end

      it "does not return app_events with inline-relations-depth=1 since app_events dataset is relatively expensive to query" do
        org = Organization.make
        get "/v2/organizations/#{org.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end
    end

    describe "Deprecated endpoints" do
      let!(:domain) { SharedDomain.make }
      describe "DELETE /v2/organizations/:guid/domains/:shared_domain_guid" do
        it "should pretends that it deleted a domain" do
          expect{delete "/v2/organizations/#{org.guid}/domains/#{domain.guid}", {},
                        headers_for(@org_a_manager)}.not_to change{SharedDomain.count}
          last_response.status.should == 301
          expect(last_response.headers).to include("X-Cf-Warning" => "Endpoint removed")
        end
      end

      describe "GET /v2/organizations/:guid/domains/:guid" do
        it "should be deprecated" do
          get "/v2/organizations/#{org.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe "PUT /v2/organizations/:guid/domains/:domain_guid" do
        it "should be deprecated" do
          put "/v2/organizations/#{org.guid}/domains/#{domain.guid}", {}, admin_headers
          expect(last_response.status).to eql(201)
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe "PUT /v2/organizations/:guid/domains/:private_domain_guid" do
        let(:private_domain) { PrivateDomain.make(owning_organization: org) }
        it "should be deprecated" do
          expect(org.domains).to include(private_domain)
          put "/v2/organizations/#{org.guid}/domains/#{private_domain.guid}", {}, admin_headers
          expect(last_response.status).to eql(201)
          expect(last_response).to be_a_deprecated_response
        end
      end
    end
  end
end
