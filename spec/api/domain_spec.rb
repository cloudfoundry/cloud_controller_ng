# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Domain do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/domains",
      :model                => Models::Domain,
      :basic_attributes     => [:name, :owning_organization_guid],
      :required_attributes  => [:name, :owning_organization_guid, :wildcard],
      :unique_attributes    => :name
    }

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

      describe "System Domain permissions" do
        describe "PUT /v2/domains/:system_domain" do
          it "should not allow modification of the shared domain by an org manager" do
            @system_domain.add_organization(@org_a)
            put "/v2/domains/#{@system_domain.guid}",
                Yajl::Encoder.encode(:name => Sham.domain),
                headers_for(@org_a_manager)
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
