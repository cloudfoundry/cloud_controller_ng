# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::ServicePlan do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/service_plans",
    :model                => VCAP::CloudController::Models::ServicePlan,
    :basic_attributes     => [:name, :description, :service_guid],
    :required_attributes  => [:name, :description, :service_guid],
    :unique_attributes    => [:name, :service_guid],
    :one_to_many_collection_ids  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    }
  }

  shared_examples "enumerate and read plan only" do |perm_name|
    include_examples "permission checks", perm_name,
      :model => VCAP::CloudController::Models::ServicePlan,
      :path => "/v2/service_plans",
      :permissions_overlap => true,
      :enumerate => 7,
      :create => :not_allowed,
      :read => :allowed,
      :modify => :not_allowed,
      :delete => :not_allowed
  end

  describe "Permissions" do
    include_context "permissions"

    before do
      5.times do
        Models::ServicePlan.make
      end
      @obj_a = Models::ServicePlan.make
      @obj_b = Models::ServicePlan.make
    end

    let(:creation_req_for_a) do
      Yajl::Encoder.encode(
        :service_guid => Models::Service.make.guid,
        :name => Sham.name,
        :description => Sham.description)
    end

    let(:update_req_for_a) do
      Yajl::Encoder.encode(:description => Sham.description)
    end

    describe "Org Level Permissions" do
      describe "OrgManager" do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @org_b_manager }

        include_examples "enumerate and read plan only", "OrgManager"
      end

      describe "OrgUser" do
        let(:member_a) { @org_a_member }
        let(:member_b) { @org_b_member }

        include_examples "enumerate and read plan only", "OrgUser"
      end

      describe "BillingManager" do
        let(:member_a) { @org_a_billing_manager }
        let(:member_b) { @org_b_billing_manager }

        include_examples "enumerate and read plan only", "BillingManager"
      end

      describe "Auditor" do
        let(:member_a) { @org_a_auditor }
        let(:member_b) { @org_b_auditor }

        include_examples "enumerate and read plan only", "Auditor"
      end
    end

    describe "App Space Level Permissions" do
      describe "AppSpaceManager" do
        let(:member_a) { @app_space_a_manager }
        let(:member_b) { @app_space_b_manager }

        include_examples "enumerate and read plan only", "AppSpaceManager"
      end

      describe "Developer" do
        let(:member_a) { @app_space_a_developer }
        let(:member_b) { @app_space_b_developer }

        include_examples "enumerate and read plan only", "Developer"
      end

      describe "AppSpaceAuditor" do
        let(:member_a) { @app_space_a_auditor }
        let(:member_b) { @app_space_b_auditor }

        include_examples "enumerate and read plan only", "AppSpaceAuditor"
      end
    end
  end
end
