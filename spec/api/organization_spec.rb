# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Organization do

  let(:org)   { VCAP::CloudController::Models::Organization.make }

  it_behaves_like "a CloudController API", {
    :path                => "/v2/organizations",
    :model               => VCAP::CloudController::Models::Organization,
    :basic_attributes    => :name,
    :required_attributes => :name,
    :unique_attributes   => :name,
    :many_to_many_collection_ids => {
      :users    => lambda { |org| VCAP::CloudController::Models::User.make },
      :managers => lambda { |org| VCAP::CloudController::Models::User.make },
      :billing_managers => lambda { |org| VCAP::CloudController::Models::User.make }
    },
    :one_to_many_collection_ids  => {
      :app_spaces => lambda { |org| VCAP::CloudController::Models::AppSpace.make }
    }
  }

  shared_examples "enumerate orgs ok" do |perm_name|
    describe "GET /v2/organizations" do
      it "should return orgs to a user that has #{perm_name} permissions" do
        get "/v2/organizations", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@org_a.guid]

        get "/v2/organizations", {}, headers_for(member_b)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@org_b.guid]
      end

      it "should not return orgs to a user with the #{perm_name} permission on a different org" do
        get "/v2/organizations/#{@org_b.guid}", {}, headers_for(@org_a_manager)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "modify org ok" do |perm_name|
    describe "PUT /v2/organizations/:id" do
      it "should allow a user with the #{perm_name} permission to modify an org" do
        put "/v2/organizations/#{@org_a.guid}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @org_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on a different org to modify an org" do
        put "/v2/organizations/#{@org_a.guid}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(member_b))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify org fail" do |perm_name|
    describe "PUT /v2/organizations/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify an org" do
        put "/v2/organizations/#{@org_a.guid}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "read org ok" do |perm_name|
    describe "GET /v2/organizations/:id" do
      it "should allow a user with the #{perm_name} permission to read an org" do
        get "/v2/organizations/#{@org_a.guid}", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["metadata"]["guid"].should == @org_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on another org to read an org" do
        get "/v2/organizations/#{@org_a.guid}", {}, headers_for(member_b)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "delete org ok" do |perm_name|
    describe "DELETE /v2/organizations/:id" do
      it "should allow a user with the #{perm_name} permission to delete an org" do
        delete "/v2/organizations/#{@org_a.guid}", {}, headers_for(member_a)
        last_response.status.should == 204
      end

      it "should not allow a user with the #{perm_name} permission on a different org to delete an org" do
        delete "/v2/organizations/#{@org_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete org fail" do |perm_name|
    describe "DELETE /v2/organizations/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete an org" do
        delete "/v2/organizations/#{@org_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  describe "Permissions" do
    before do
      @org_a = VCAP::CloudController::Models::Organization.make
      @org_a_manager = VCAP::CloudController::Models::User.make
      @org_a_member = VCAP::CloudController::Models::User.make
      @org_a_billing_manager = VCAP::CloudController::Models::User.make
      @org_a_auditor = VCAP::CloudController::Models::User.make
      @org_a.add_manager(@org_a_manager)
      @org_a.add_user(@org_a_member)
      @org_a.add_billing_manager(@org_a_billing_manager)
      @org_a.add_auditor(@org_a_auditor)

      @org_b = VCAP::CloudController::Models::Organization.make
      @org_b_manager = VCAP::CloudController::Models::User.make
      @org_b_member = VCAP::CloudController::Models::User.make
      @org_b_billing_manager = VCAP::CloudController::Models::User.make
      @org_b_auditor = VCAP::CloudController::Models::User.make
      @org_b.add_manager(@org_b_manager)
      @org_b.add_user(@org_b_member)
      @org_b.add_billing_manager(@org_b_billing_manager)
      @org_b.add_auditor(@org_b_auditor)

      @cf_admin = VCAP::CloudController::Models::User.make(:admin => true)
    end

    describe "OrgManager" do
      let(:member_a) { @org_a_manager }
      let(:member_b) { @org_b_manager }

      include_examples "enumerate orgs ok", "OrgManager"
      include_examples "modify org ok", "OrgManager"
      include_examples "read org ok", "OrgManager"
      include_examples "delete org ok", "OrgManager"
    end

    describe "OrgUser" do
      let(:member_a) { @org_a_member }
      let(:member_b) { @org_b_member }

      include_examples "enumerate orgs ok", "OrgUser"
      include_examples "modify org fail", "OrgUser"
      include_examples "read org ok", "OrgUser"
      include_examples "delete org fail", "OrgUser"
    end

    describe "BillingManager" do
      let(:member_a) { @org_a_billing_manager }
      let(:member_b) { @org_b_billing_manager }

      include_examples "enumerate orgs ok", "BillingManager"
      include_examples "modify org fail", "BillingManager"
      include_examples "read org ok", "BillingManager"
      include_examples "delete org fail", "BillingManager"
    end

    describe "Auditor" do
      let(:member_a) { @org_a_auditor }
      let(:member_b) { @org_b_auditor }

      include_examples "enumerate orgs ok", "Auditor"
      include_examples "modify org fail", "Auditor"
      include_examples "read org ok", "Auditor"
      include_examples "delete org fail", "Auditor"
    end

    describe "CFAdmin" do
      it "should allow a user with the CFAdmin permission to enumerate all orgs" do
        get "/v2/organizations", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == 2
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@org_a.guid, @org_b.guid]
      end

      it "should allow a user with the CFAdmin permission to read any org" do
        get "/v2/organizations/#{@org_a.guid}", {}, headers_for(@cf_admin)
        last_response.should be_ok
      end

      it "should allow a user with the CFAdmin permission to modify any org" do
        put "/v2/organizations/#{@org_a.guid}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(@cf_admin))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @org_a.guid
      end

      it "should allow a user with the CFAdmin permission to delete an org" do
        delete "/v2/organizations/#{@org_a.guid}", {}, headers_for(@cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
end
