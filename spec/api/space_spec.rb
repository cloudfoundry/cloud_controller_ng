# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Space do
    it_behaves_like "a CloudController API", {
      :path                => "/v2/spaces",
      :model               => Models::Space,
      :basic_attributes    => [:name, :organization_guid],
      :required_attributes => [:name, :organization_guid],
      :unique_attributes   => [:name, :organization_guid],
      :queryable_attributes => :name,
      :many_to_many_collection_ids => {
        :developers => lambda { |space| make_user_for_space(space) },
        :managers   => lambda { |space| make_user_for_space(space) },
        :auditors   => lambda { |space| make_user_for_space(space) },
        :domains    => lambda { |space| make_domain_for_space(space) }
      },
      :one_to_many_collection_ids => {
        :apps  => lambda { |space| Models::App.make },
        :service_instances => lambda { |space| Models::ServiceInstance.make }
      }
    }

    describe "data integrity" do
      let(:cf_admin) { Models::User.make(:admin => true) }
      let(:space) { Models::Space.make }

      it "should not make strings into integers" do
        space.name = "1234"
        space.save
        get "/v2/spaces/#{space.guid}", {}, headers_for(cf_admin)
        decoded_response["entity"]["name"].should == "1234"
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @space_a
        @obj_b = @space_b
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name, :organization_guid => @org_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::Space,
            :path => "/v2/spaces",
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
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission checks", "SpaceManager",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::Space,
            :path => "/v2/spaces",
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
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end
  end
end
