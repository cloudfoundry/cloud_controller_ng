# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Route do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/routes",
    :model                => VCAP::CloudController::Models::Route,
    :basic_attributes     => [:host, :domain_guid, :organization_guid],
    :required_attributes  => [:host, :domain_guid, :organization_guid],
    :update_attributes    => [:host],
    :unique_attributes    => [:host, :domain_guid]
  }

  describe "Permissions" do

    shared_examples "route permissions" do
      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
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
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => VCAP::CloudController::Models::Route,
            :path => "/v2/routes",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    context "with a custom domain" do
      include_context "permissions"

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:host => Sham.host,
                             :domain_guid => @domain_a.guid,
                             :organization_guid => @org_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:host => Sham.host)
      end

      before do
        @domain_a = Models::Domain.make(:owning_organization => @org_a)
        @space_a.add_domain(@domain_a)
        @obj_a = Models::Route.make(:domain => @domain_a, :organization => @org_a)

        @domain_b = Models::Domain.make(:owning_organization => @org_b)
        @space_b.add_domain(@domain_b)
        @obj_b = Models::Route.make(:domain => @domain_b, :organization => @org_b)
      end

      include_examples "route permissions"
    end

    context "with the default serving domain" do
      include_context "permissions"

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :host => Sham.host,
          :domain_guid => Models::Domain.default_serving_domain.guid,
          :organization_guid => @org_a.guid
        )
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:host => Sham.host)
      end

      before do
        Models::Domain.default_serving_domain_name = "shared.com"

        @obj_a = Models::Route.make(
          :domain => Models::Domain.default_serving_domain,
          :organization => @org_a
        )

        @obj_b = Models::Route.make(
          :domain => Models::Domain.default_serving_domain,
          :organization => @org_b
        )
      end

      after do
        Models::Domain.default_serving_domain_name = nil
      end

      include_examples "route permissions"
    end
  end
end
