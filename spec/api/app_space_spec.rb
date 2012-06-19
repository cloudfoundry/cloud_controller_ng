# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::AppSpace do

  it_behaves_like "a CloudController API", {
    :path                => "/v2/app_spaces",
    :model               => VCAP::CloudController::Models::AppSpace,
    :basic_attributes    => [:name, :organization_guid],
    :required_attributes => [:name, :organization_guid],
    :unique_attributes   => [:name, :organization_guid],
    :many_to_many_collection_ids => {
      :developers => lambda { |app_space| make_user_for_app_space(app_space) },
      :managers   => lambda { |app_space| make_user_for_app_space(app_space) },
      :auditors   => lambda { |app_space| make_user_for_app_space(app_space) },
      :domains    => lambda { |app_space| make_domain_for_app_space(app_space) }
    },
    :one_to_many_collection_ids => {
      :apps  => lambda { |app_space| VCAP::CloudController::Models::App.make }
    }
  }

  shared_examples "enumerate app spaces ok" do |perm_name, expected|
    expected ||= 1
    describe "GET /v2/app_spaces" do
      it "should return #{expected} app_spaces to a user that has #{perm_name} permissions" do
        get "/v2/app_spaces", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected == 1
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@app_space_a.guid]
        end

        get "/v2/app_spaces", {}, headers_for(member_b)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected == 1
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@app_space_b.guid]
        end
      end

      it "should not return app spaces to a user with the #{perm_name} permission on a different app space" do
        get "/v2/app_spaces/#{@app_space_b.guid}", {}, headers_for(@member_a)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "create app space ok" do |perm_name|
    describe "POST /v2/app_spaces/:id" do
      it "should allow a user with the #{perm_name} permission to create an app space in an org" do
        before_count = VCAP::CloudController::Models::AppSpace.all.count
        post "/v2/app_spaces", Yajl::Encoder.encode({ :name => Sham.name, :organization_guid => @org_a.guid }), json_headers(headers_for(member_a))
        last_response.status.should == 201
        VCAP::CloudController::Models::AppSpace.count.should == before_count + 1
      end

      it "should not allow a user with the #{perm_name} permission on a different org to create an app space" do
        before_count = VCAP::CloudController::Models::AppSpace.all.count
        post "/v2/app_spaces", Yajl::Encoder.encode({ :name => Sham.name, :organization_guid => @org_a.guid }), json_headers(headers_for(member_b))
        last_response.status.should == 403
        VCAP::CloudController::Models::AppSpace.count.should == before_count
      end
    end
  end

  shared_examples "create app space fail" do |perm_name|
    describe "POST /v2/app_spaces/:id" do
      it "should not allow a user with only the #{perm_name} permission to create an app space" do
        post "/v2/app_spaces", Yajl::Encoder.encode({ :name => Sham.name, :organization_guid => @org_a.guid }), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify app space ok" do |perm_name|
    describe "PUT /v2/app_spaces/:id" do
      it "should allow a user with the #{perm_name} permission to modify an app space" do
        put "/v2/app_spaces/#{@app_space_a.guid}", Yajl::Encoder.encode({ :name => "#{@app_space_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @app_space_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on a different app space to modify an app space" do
        put "/v2/app_spaces/#{@app_space_a.guid}", Yajl::Encoder.encode({ :name => "#{@app_space_a.name}_renamed" }), json_headers(headers_for(member_b))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify app space fail" do |perm_name|
    describe "PUT /v2/app_spaces/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify an app space" do
        put "/v2/app_spaces/#{@app_space_a.guid}", Yajl::Encoder.encode({ :name => "#{@app_space_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "read app space ok" do |perm_name|
    describe "GET /v2/app_spaces/:id" do
      it "should allow a user with the #{perm_name} permission to read an app space" do
        get "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["metadata"]["guid"].should == @app_space_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on another app space to read an app space" do
        get "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_b)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "read app space fail" do |perm_name|
    describe "GET /v2/app_spaces/:id" do
      it "should not allow a user with only the #{perm_name} permission to read an app space" do
        get "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete app space ok" do |perm_name|
    describe "DELETE /v2/app_spaces/:id" do
      it "should allow a user with the #{perm_name} permission to delete an app space" do
        delete "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_a)
        last_response.status.should == 204
      end

      it "should not allow a user with the #{perm_name} permission on a different app space to delete an app space" do
        delete "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete app space fail" do |perm_name|
    describe "DELETE /v2/app_spaces/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete an app space" do
        delete "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  describe "Permissions" do
    include_context "permissions"

    describe "Org Level Permissions" do
      describe "OrgManager" do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @org_b_manager }

        include_examples "create app space ok", "OrgManager"
        include_examples "enumerate app spaces ok", "OrgManager"
        include_examples "modify app space ok", "OrgManager"
        include_examples "read app space ok", "OrgManager"
        include_examples "delete app space ok", "OrgManager"
      end

      describe "OrgUser" do
        let(:member_a) { @org_a_member }
        let(:member_b) { @org_b_member }

        include_examples "create app space fail", "OrgUser"
        include_examples "enumerate app spaces ok", "OrgUser", 0
        include_examples "modify app space fail", "OrgUser"
        include_examples "read app space fail", "OrgUser"
        include_examples "delete app space fail", "OrgUser"
      end

      describe "BillingManager" do
        let(:member_a) { @org_a_billing_manager }
        let(:member_b) { @org_b_billing_manager }

        include_examples "create app space fail", "BillingManager"
        include_examples "enumerate app spaces ok", "BillingManager", 0
        include_examples "modify app space fail", "BillingManager"
        include_examples "read app space fail", "BillingManager"
        include_examples "delete app space fail", "BillingManager"
      end

      describe "Auditor" do
        let(:member_a) { @org_a_auditor }
        let(:member_b) { @org_b_auditor }

        include_examples "create app space fail", "BillingManager"
        include_examples "enumerate app spaces ok", "BillingManager", 0
        include_examples "modify app space fail", "BillingManager"
        include_examples "read app space fail", "BillingManager"
        include_examples "delete app space fail", "BillingManager"
      end
    end

    describe "App Space Level Permissions" do
      describe "AppSpaceManager" do
        let(:member_a) { @app_space_a_manager }
        let(:member_b) { @app_space_b_manager }

        include_examples "create app space fail", "AppSpaceManager"
        include_examples "enumerate app spaces ok", "AppSpaceManager"
        include_examples "modify app space ok", "AppSpaceManager"
        include_examples "read app space ok", "AppSpaceManager"
        include_examples "delete app space fail", "AppSpaceManager"
      end

      describe "Developer" do
        let(:member_a) { @app_space_a_developer }
        let(:member_b) { @app_space_b_developer }

        include_examples "create app space fail", "Developer"
        include_examples "enumerate app spaces ok", "Developer"
        include_examples "modify app space fail", "Developer"
        include_examples "read app space ok", "Developer"
        include_examples "delete app space fail", "Developer"
      end

      describe "AppSpaceAuditor" do
        let(:member_a) { @app_space_a_auditor }
        let(:member_b) { @app_space_b_auditor }

        include_examples "create app space fail", "AppSpaceAuditor"
        include_examples "enumerate app spaces ok", "AppSpaceAuditor"
        include_examples "modify app space fail", "AppSpaceAuditor"
        include_examples "read app space ok", "AppSpaceAuditor"
        include_examples "delete app space fail", "AppSpaceAuditor"
      end
    end

    describe "CFAdmin" do
      it "should allow a user with the CFAdmin permission to enumerate all app spaces" do
        get "/v2/app_spaces", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == Models::Organization.all.count
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should ==
          Models::AppSpace.select(:guid).collect { |o| o.guid }
      end

      it "should allow a user with the CFAdmin permission to read any app space" do
        get "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(@cf_admin)
        last_response.should be_ok
      end

      it "should allow a user with the CFAdmin permission to modify any app space" do
        put "/v2/app_spaces/#{@app_space_a.guid}", Yajl::Encoder.encode({ :name => "#{@app_space_a.name}_renamed" }), json_headers(headers_for(@cf_admin))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @app_space_a.guid
      end

      it "should allow a user with the CFAdmin permission to delete an app space" do
        delete "/v2/app_spaces/#{@app_space_a.guid}", {}, headers_for(@cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
