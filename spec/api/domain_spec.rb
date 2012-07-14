# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Domain do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/domains",
    :model                => VCAP::CloudController::Models::Domain,
    :basic_attributes     => [:name, :organization_guid],
    :required_attributes  => [:name, :organization_guid],
    :unique_attributes    => :name
  }

  describe "Permissions" do
    include_context "permissions"

    before do
      @obj_a = VCAP::CloudController::Models::Domain.make(:organization => @org_a)
      @app_space_a.add_domain(@obj_a)

      @obj_b = VCAP::CloudController::Models::Domain.make(:organization => @org_b)
      @app_space_b.add_domain(@obj_b)
    end

    let(:creation_req_for_a) do
      Yajl::Encoder.encode(:name => Sham.domain, :organization_guid => @org_a.guid)
    end

    let(:update_req_for_a) do
      Yajl::Encoder.encode(:name => Sham.domain)
    end

    describe "Org Level Permissions" do
      describe "OrgManager" do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @org_b_manager }

        include_examples "permission checks", "OrgManager",
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
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
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
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
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
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
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
          :enumerate => 0,
          :create => :not_allowed,
          :read => :not_allowed,
          :modify => :not_allowed,
          :delete => :not_allowed
      end
    end

    describe "App Space Level Permissions" do
      describe "AppSpaceManager" do
        let(:member_a) { @app_space_a_manager }
        let(:member_b) { @app_space_b_manager }

        include_examples "permission checks", "AppSpaceManager",
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
          :enumerate => 0,
          :create => :not_allowed,
          :read => :allowed,
          :modify => :not_allowed,
          :delete => :not_allowed
      end

      describe "Developer" do
        let(:member_a) { @app_space_a_developer }
        let(:member_b) { @app_space_b_developer }

        include_examples "permission checks", "Developer",
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
          :enumerate => 0,
          :create => :not_allowed,
          :read => :allowed,
          :modify => :not_allowed,
          :delete => :not_allowed
      end

      describe "AppSpaceAuditor" do
        let(:member_a) { @app_space_a_auditor }
        let(:member_b) { @app_space_b_auditor }

        include_examples "permission checks", "AppSpaceAuditor",
          :model => VCAP::CloudController::Models::Domain,
          :path => "/v2/domains",
          :enumerate => 0,
          :create => :not_allowed,
          :read => :allowed,
          :modify => :not_allowed,
          :delete => :not_allowed
      end
    end
  end
end
