require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DomainsController do
    it_behaves_like "an authenticated endpoint", path: "/v2/domains"
    include_examples "enumerating objects", path: "/v2/domains", model: PrivateDomain
    include_examples "enumerating objects", path: "/v2/domains", model: SharedDomain
    include_examples "reading a valid object", path: "/v2/domains", model: PrivateDomain, basic_attributes: %w(name owning_organization_guid)
    include_examples "reading a valid object", path: "/v2/domains", model: SharedDomain, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/domains"
    include_examples "creating and updating", path: "/v2/domains", model: SharedDomain, required_attributes: %w(name), unique_attributes: %w(name)
    include_examples "deleting a valid object", path: "/v2/domains", model: PrivateDomain,
      one_to_many_collection_ids: {
        routes: lambda { |domain|
          space = Space.make(organization: domain.owning_organization)
          Route.make(domain: domain, space: space)
        }
      }
    include_examples "deleting a valid object", path: "/v2/domains", model: SharedDomain, one_to_many_collection_ids: {routes: lambda { |domain| Route.make(domain: domain) }}

    include_examples "collection operations", path: "/v2/domains", model: PrivateDomain,
      one_to_many_collection_ids: {},
      many_to_one_collection_ids: {owning_organization: lambda { |user| user.organizations.first || Organization.make }},
      many_to_many_collection_ids: {}

    include_examples "collection operations", path: "/v2/domains", model: SharedDomain,
      one_to_many_collection_ids: {},
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}

    describe "Permissions" do
      include_context "permissions"

      before do
        @shared_domain = SharedDomain.make

        @obj_a = PrivateDomain.make(owning_organization: @org_a)

        @obj_b = PrivateDomain.make(owning_organization: @org_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.domain,
                             :wildcard => true,
                             :owning_organization_guid => @org_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.domain)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }
          let(:enumeration_expectation_a) { [@obj_a, @shared_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @shared_domain] }

          include_examples "permission enumeration", "OrgManager",
            :name => 'domain',
            :path => "/v2/domains",
            :enumerate => 2
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }
          let(:enumeration_expectation_a) { [@shared_domain] }
          let(:enumeration_expectation_b) { [@shared_domain] }

          include_examples "permission enumeration", "OrgUser",
            :name => 'domain',
            :path => "/v2/domains",
            :enumerate => 1
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }
          let(:enumeration_expectation_a) { [@shared_domain] }
          let(:enumeration_expectation_b) { [@shared_domain] }

          include_examples "permission enumeration", "BillingManager",
            :name => 'domain',
            :path => "/v2/domains",
            :enumerate => 1
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }
          let(:enumeration_expectation_a) { [@obj_a, @shared_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @shared_domain] }

          include_examples "permission enumeration", "Auditor",
            :name => 'domain',
            :path => "/v2/domains",
            :enumerate => 2
        end
      end

      describe "System Domain permissions" do
        describe "PUT /v2/domains/:system_domain" do
          it "should not allow modification of the shared domain by an org manager" do
            put "/v2/domains/#{@shared_domain.guid}",
                Yajl::Encoder.encode(name: Sham.domain),
                json_headers(headers_for(@org_a_manager))
            last_response.status.should == 403
          end
        end
      end
 end

    describe "GET /v2/domains/:id" do
      let(:user) { User.make }
      let(:organization) { Organization.make }

      before do
        organization.add_user(user)
        organization.add_manager(user)
        organization.add_billing_manager(user)
        organization.add_auditor(user)
      end

      context "when the domain has an owning organization" do
        let(:domain) { PrivateDomain.make(owning_organization: organization) }

        it "has its GUID and URL in the response body" do
          get "/v2/domains/#{domain.guid}", {}, json_headers(headers_for(user))

          expect(last_response.status).to eq 200
          expect(decoded_response["entity"]["owning_organization_guid"]).to eq organization.guid
          expect(decoded_response["entity"]["owning_organization_url"]).to eq "/v2/organizations/#{organization.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end

      context "when the domain is shared" do
        let(:domain) { SharedDomain.make }

        it "has its GUID as null, and no url key in the response body" do
          get "/v2/domains/#{domain.guid}", {}, json_headers(admin_headers)

          last_response.status.should == 200

          json = Yajl::Parser.parse(last_response.body)
          json["entity"]["owning_organization_guid"].should be_nil

          json["entity"].should_not include("owning_organization_url")
          expect(last_response).to be_a_deprecated_response
        end
      end
    end

    describe "POST /v2/domains" do
      context "with a private domain (shared domain is meta programmed tested)" do
        let(:user) { User.make }
        let(:organization) { Organization.make }

        before do
          organization.add_user(user)
          organization.add_manager(user)
          organization.add_billing_manager(user)
          organization.add_auditor(user)
        end

        it "should create a domain with the specified name and owning organization" do
          name = Sham.domain
          post "/v2/domains", Yajl::Encoder.encode(name: name, owning_organization_guid: organization.guid), json_headers(headers_for(user))
          expect(last_response.status).to eq 201
          expect(decoded_response["entity"]["name"]).to eq name
          expect(decoded_response["entity"]["owning_organization_guid"]).to eq organization.guid
          expect(last_response).to be_a_deprecated_response
        end
      end
    end

    describe "DELETE /v2/domains/:id" do
      let(:shared_domain) { SharedDomain.make }

      context "when there are routes using the domain" do
        let!(:route) { Route.make(domain: shared_domain) }

        it "should dot delete the route" do
          expect {
            delete "/v2/domains/#{shared_domain.guid}", {}, admin_headers
          }.to_not change {
            SharedDomain.find(guid: shared_domain.guid)
          }
        end

        it "should return an error" do
          delete "/v2/domains/#{shared_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(400)
          expect(decoded_response["code"]).to equal(10006)
          expect(decoded_response["description"]).to match /delete the routes associations for your domains/i
        end
      end

      context "deprecation" do
        it "has the correct deprecation header" do
          delete "/v2/domains/#{shared_domain.guid}", {}, admin_headers
          expect(last_response).to be_a_deprecated_response
        end
      end
    end
  end

  describe "GET /v2/domains/:id/spaces" do
    let!(:private_domain) { PrivateDomain.make }
    let!(:space) { Space.make(organization: private_domain.owning_organization) }

    it "returns the spaces associated with the owning organization" do
      get "/v2/domains/#{private_domain.guid}/spaces", {}, admin_headers
      expect(last_response.status).to eq(200)
      expect(decoded_response["resources"]).to have(1).item
      expect(decoded_response["resources"][0]["entity"]["name"]).to eq(space.name)
      expect(last_response).to be_a_deprecated_response
    end
  end
end
