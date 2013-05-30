# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Organization do
    let(:org) { Models::Organization.make }
    include_examples "uaa authenticated api", path: "/v2/organizations"
    include_examples "querying objects", path: "/v2/organizations", model: Models::Organization, queryable_attributes: %w(name status)
    include_examples "enumerating objects", path: "/v2/organizations", model: Models::Organization
    include_examples "reading a valid object", path: "/v2/organizations", model: Models::Organization, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/organizations"
    include_examples "creating and updating", path: "/v2/organizations", model: Models::Organization, required_attributes: %w(name), unique_attributes: %w(name), extra_attributes: []
    include_examples "deleting a valid object", path: "/v2/organizations", model: Models::Organization,
      one_to_many_collection_ids: {:spaces => lambda { |org| Models::Space.make(:organization => org) }},
      one_to_many_collection_ids_without_url: {
        :service_instances => lambda { |org|
          space = Models::Space.make(:organization => org)
          Models::ServiceInstance.make(:space => space)
        },
        :apps => lambda { |org|
          space = Models::Space.make(:organization => org)
          Models::App.make(:space => space)
        },
        :owned_domain => lambda { |org|
          Models::Domain.make(:owning_organization => org)
        }
      }
    include_examples "collection operations", path: "/v2/organizations", model: Models::Organization,
      one_to_many_collection_ids: {
        spaces: lambda { |org| Models::Space.make(organization: org) }
      },
      one_to_many_collection_ids_without_url: {
        service_instances: lambda { |org| Models::ServiceInstance.make(space: Models::Space.make(organization: org)) },
        apps: lambda { |org| Models::App.make(space: Models::Space.make(organization: org)) },
        owned_domain: lambda { |org| Models::Domain.make(owning_organization: org) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {
        users: lambda { |org| Models::User.make },
        managers: lambda { |org| Models::User.make },
        billing_managers: lambda { |org| Models::User.make },
        domains: lambda { |org| Models::Domain.find_or_create_shared_domain(Sham.domain) }
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

          include_examples "permission checks", "OrgManager",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :not_allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission checks", "SpaceManager",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::Organization,
            :path => "/v2/organizations",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe "billing" do
      let(:org_admin_headers) do
        user = Models::User.make
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
          put "/v2/organizations/#{org.guid}", req, admin_headers
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
          put "/v2/organizations/#{org.guid}", req, org_admin_headers
          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == false
        end

        it "should not be allowed to set billing_enabled flag to false" do
          org.billing_enabled = true
          org.save(:validate => false)
          req = Yajl::Encoder.encode(:billing_enabled => false)
          put "/v2/organizations/#{org.guid}", req, org_admin_headers
          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == true
        end
      end
    end


    describe "updating the 'can_access_non_public_plans' field" do
      let(:non_admin_headers) { headers_for(Models::User.make(:admin => false)) }

      it "can be updated by cf admins" do
        req = Yajl::Encoder.encode(:can_access_non_public_plans => true)
        expect {
          put "/v2/organizations/#{org.guid}", req, admin_headers
        }.to change { org.reload.can_access_non_public_plans }.to(true)
        last_response.status.should == 201
      end

      it "cannot be updated by people who aren't cf-admins" do
        req = Yajl::Encoder.encode(:can_access_non_public_plans => true)
        expect {
          put "/v2/organizations/#{org.guid}", req, non_admin_headers
        }.not_to change { org.reload.can_access_non_public_plans }.from(false)
        last_response.status.should == 403
      end
    end

    describe "quota definition" do
      let(:org_admin_headers) do
        user = Models::User.make
        org.add_user(user)
        org.add_manager(user)
        headers_for(user)
      end

      let(:quota_definition) do
        Models::QuotaDefinition.make
      end

      let(:update_request) do
        Yajl::Encoder.encode(:quota_definition_guid => quota_definition.guid)
      end

      describe "cf admins" do
        it "should be allowed to set the quota definition" do
          put "/v2/organizations/#{org.guid}", update_request, admin_headers
          last_response.status.should == 201
          org.refresh
          org.quota_definition.should == quota_definition
        end
      end

      describe "org admins" do
        it "should not be allowed to set the quota definition" do
          orig_quota_definition = org.quota_definition
          put "/v2/organizations/#{org.guid}", update_request, org_admin_headers
          last_response.status.should == 400
          org.refresh
          org.quota_definition.should == orig_quota_definition
        end
      end
    end
  end
end
