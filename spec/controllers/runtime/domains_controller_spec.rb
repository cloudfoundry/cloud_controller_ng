require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DomainsController, type: :controller do
    it "is temporarily disabled" do
      pending "Splitting domain into private and shared domains. This will remain for the deprecated endpoint."
    end

    next

    include_examples "uaa authenticated api", path: "/v2/domains"
    include_examples "enumerating objects", path: "/v2/domains", model: Domain
    include_examples "reading a valid object", path: "/v2/domains", model: Domain, basic_attributes: %w(name owning_organization_guid)
    include_examples "operations on an invalid object", path: "/v2/domains"
    include_examples "creating and updating", path: "/v2/domains", model: Domain, required_attributes: %w(name wildcard), unique_attributes: %w(name)
    include_examples "deleting a valid object", path: "/v2/domains", model: Domain,
      one_to_many_collection_ids: {
        routes: lambda { |domain|
          domain.update(wildcard: true)
          space = Space.make(organization: domain.owning_organization)
          Route.make(
            host: Sham.host,
            domain: domain,
            space: space,
          )
        }
      }

    include_examples "collection operations", path: "/v2/domains", model: Domain,
      one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {
        :routes => lambda { |domain|
          domain.update(wildcard: true)
          space = Space.make(organization: domain.owning_organization)
          Route.make(host: Sham.host, domain: domain, space: space)
        }
      },
      many_to_one_collection_ids: {
        owning_organization: lambda { |user| user.organizations.first || Organization.make }
      },
      many_to_many_collection_ids: {}
    before do
      pending "Splitting domain into private and shared domains. This will remain for the deprecated endpoint."
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @shared_domain = SharedDomain.new(:name => Sham.domain,
                                            :owning_organization => nil)
        @shared_domain.save(:validate => false)

        @obj_a = PrivateDomain.make(:owning_organization => @org_a)

        @obj_b = PrivateDomain.make(:owning_organization => @org_b)
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
            @shared_domain.add_organization(@org_a)
            put "/v2/domains/#{@shared_domain.guid}",
                Yajl::Encoder.encode(:name => Sham.domain),
                json_headers(headers_for(@org_a_manager))
            last_response.status.should == 403
          end
        end

        describe "DELETE /v2/organizations/:id/domains/:system_domain" do
          it "should be allowed for the org admin" do
            delete "/v2/organizations/#{@org_a.guid}/domains/#{@shared_domain.guid}", {},
                   headers_for(@org_a_manager)
            last_response.status.should == 201
          end

          it "should not be allowed for an org member" do
            delete "/v2/organizations/#{@org_a.guid}/domains/#{@shared_domain.guid}", {},
                   headers_for(@org_a_member)
            last_response.status.should == 403
          end
        end
      end
    end

    describe "GET /v2/domains/:id" do
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:domain) { Domain.make }

      before do
        organization.add_user(user)
        organization.add_manager(user)
        organization.add_billing_manager(user)
        organization.add_auditor(user)
      end

      context "when the domain has an owning organization" do
        before { domain.update(:owning_organization => organization) }

        it "has its GUID and URL in the response body" do
          get "/v2/domains/#{domain.guid}", {}, json_headers(headers_for(user))

          last_response.status.should == 200

          json = Yajl::Parser.parse(last_response.body)
          json["entity"]["owning_organization_guid"].should == \
            organization.guid

          json["entity"]["owning_organization_url"].should == \
            "/v2/organizations/#{organization.guid}"
        end
      end

      context "when the domain does NOT have an owning organization" do
        before { domain.update(:owning_organization => nil) }

        it "has its GUID as null, and no url key in the response body" do
          get "/v2/domains/#{domain.guid}", {}, json_headers(admin_headers)

          last_response.status.should == 200

          json = Yajl::Parser.parse(last_response.body)
          json["entity"]["owning_organization_guid"].should be_nil

          json["entity"].should_not include("owning_organization_url")
        end
      end
    end
  end
end
