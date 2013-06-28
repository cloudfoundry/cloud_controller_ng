# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Domain do
    include_examples "uaa authenticated api", path: "/v2/domains"
    include_examples "enumerating objects", path: "/v2/domains", model: Models::Domain
    include_examples "reading a valid object", path: "/v2/domains", model: Models::Domain, basic_attributes: %w(name owning_organization_guid)
    include_examples "operations on an invalid object", path: "/v2/domains"
    include_examples "creating and updating", path: "/v2/domains", model: Models::Domain, required_attributes: %w(name owning_organization_guid wildcard), unique_attributes: %w(name), extra_attributes: []
    include_examples "deleting a valid object", path: "/v2/domains", model: Models::Domain,
      one_to_many_collection_ids: {
        :spaces => lambda { |domain|
          org = domain.organizations.first || Models::Organization.make
          Models::Space.make(:organization => org)
        },
      },
      one_to_many_collection_ids_without_url: {
        :routes => lambda { |domain|
          domain.update(:wildcard => true)
          space = Models::Space.make(:organization => domain.owning_organization)
          space.add_domain(domain)
          Models::Route.make(
            :host => Sham.host,
            :domain => domain,
            :space => space,
          )
        }
      }
    include_examples "collection operations", path: "/v2/domains", model: Models::Domain,
      one_to_many_collection_ids: {
        spaces: lambda { |domain|
          org = domain.organizations.first || Models::Organization.make
          Models::Space.make(organization: org)
        },
      },
      one_to_many_collection_ids_without_url: {
        :routes => lambda { |domain|
          domain.update(wildcard: true)
          space = Models::Space.make(organization: domain.owning_organization)
          space.add_domain(domain)
          Models::Route.make(host: Sham.host, domain: domain, space: space)
        }
      },
      many_to_one_collection_ids: {
        owning_organization: lambda { |user| user.organizations.first || Models::Organization.make }
      },
      many_to_many_collection_ids: {}

      describe "Permissions" do
      include_context "permissions"

      before(:all) do
        @system_domain = Models::Domain.new(:name => Sham.domain,
                                            :owning_organization => nil)
        @system_domain.save(:validate => false)
      end

      after(:all) do
        @system_domain.destroy
      end

      before do
        @obj_a = Models::Domain.make(:owning_organization => @org_a)
        @space_a.add_domain(@obj_a)

        @obj_b = Models::Domain.make(:owning_organization => @org_b)
        @space_b.add_domain(@obj_b)
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
          let(:enumeration_expectation_a) { [@obj_a, @system_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @system_domain] }

          include_examples "permission checks", "OrgManager",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 2,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }
          let(:enumeration_expectation_a) { [@system_domain] }
          let(:enumeration_expectation_b) { [@system_domain] }

          include_examples "permission checks", "OrgUser",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }
          let(:enumeration_expectation_a) { [@system_domain] }
          let(:enumeration_expectation_b) { [@system_domain] }

          include_examples "permission checks", "BillingManager",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }
          let(:enumeration_expectation_a) { [@obj_a, @system_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @system_domain] }

          include_examples "permission checks", "Auditor",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 2,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end

      describe "Updating space bindings" do
        before do
          @bare_domain = Models::Domain.make(:owning_organization => @org_a)
        end

        describe "PUT /v2/domains/:domain adding to spaces" do
          it "persists the change" do
            @bare_domain.space_guids.should be_empty

            put "/v2/domains/#{@bare_domain.guid}",
                Yajl::Encoder.encode(:space_guids => [@space_a.guid]),
                json_headers(headers_for(@org_a_manager))
            last_response.status.should == 201

            @bare_domain.reload
            @bare_domain.space_guids.should == [@space_a.guid]
          end
        end
      end

      describe "System Domain permissions" do
        describe "PUT /v2/domains/:system_domain" do
          it "should not allow modification of the shared domain by an org manager" do
            @system_domain.add_organization(@org_a)
            put "/v2/domains/#{@system_domain.guid}",
                Yajl::Encoder.encode(:name => Sham.domain),
                json_headers(headers_for(@org_a_manager))
            last_response.status.should == 403
          end
        end

        describe "DELETE /v2/organizations/:id/domains/:system_domain" do
          it "should be allowed for the org admin" do
            delete "/v2/organizations/#{@org_a.guid}/domains/#{@system_domain.guid}", {},
                   headers_for(@org_a_manager)
            last_response.status.should == 201
          end

          it "should not be allowed for an org member" do
            delete "/v2/organizations/#{@org_a.guid}/domains/#{@system_domain.guid}", {},
                   headers_for(@org_a_member)
            last_response.status.should == 403
          end
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }
          let(:enumeration_expectation_a) { [@obj_a, @system_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @system_domain] }

          include_examples "permission checks", "SpaceManager",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 2,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }
          let(:enumeration_expectation_a) { [@obj_a, @system_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @system_domain] }

          include_examples "permission checks", "Developer",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 2,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }
          let(:enumeration_expectation_a) { [@obj_a, @system_domain] }
          let(:enumeration_expectation_b) { [@obj_b, @system_domain] }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::Domain,
            :path => "/v2/domains",
            :enumerate => 2,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end
  end
end
