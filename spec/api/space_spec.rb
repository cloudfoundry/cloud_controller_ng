# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Space do

  it_behaves_like "a CloudController API", {
    :path                => "/v2/spaces",
    :model               => VCAP::CloudController::Models::Space,
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
      :apps  => lambda { |space| VCAP::CloudController::Models::App.make },
      :service_instances => lambda { |space| VCAP::CloudController::Models::ServiceInstance.make }
    }
  }

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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
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
          :model => VCAP::CloudController::Models::Space,
          :path => "/v2/spaces",
          :enumerate => 1,
          :create => :not_allowed,
          :read => :allowed,
          :modify => :not_allowed,
          :delete => :not_allowed
      end
    end
  end

  describe "quota" do
    let(:cf_admin) { Models::User.make(:admin => true) }
    let(:org) { Models::Organization.make }
    let(:space) { Models::Space.make }

    describe "create" do
      it "should fetch a quota token" do
        should_receive_quota_call
        post "/v2/spaces", Yajl::Encoder.encode(:name => Sham.name,
                                                    :organization_guid => org.guid),
                                                    headers_for(cf_admin)
        last_response.status.should == 201
      end
    end

    describe "get" do
      it "should not fetch a quota token" do
        should_not_receive_quota_call
        get "/v2/spaces/#{space.guid}", {}, headers_for(cf_admin)
        last_response.status.should == 200
      end
    end

    describe "update" do
      it "should fetch a quota token" do
        should_receive_quota_call
        put "/v2/spaces/#{space.guid}",
            Yajl::Encoder.encode(:name => "#{space.name}_renamed"),
            headers_for(cf_admin)
        last_response.status.should == 201
      end
    end

    describe "delete" do
      it "should fetch a quota token" do
        should_receive_quota_call
        delete "/v2/spaces/#{space.guid}", {}, headers_for(cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
