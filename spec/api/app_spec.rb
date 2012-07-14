# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::App do
  let(:app_obj) { VCAP::CloudController::Models::App.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }
  let(:runtime) { VCAP::CloudController::Models::Runtime.make }
  let(:framework) { VCAP::CloudController::Models::Framework.make }

  # FIXME: make app_space_id a relation check that checks the id and the url
  # part.  do everywhere
  it_behaves_like "a CloudController API", {
    :path                => "/v2/apps",
    :model               => VCAP::CloudController::Models::App,
    :basic_attributes    => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :required_attributes => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :unique_attributes   => [:name, :app_space_guid],

    :many_to_one_collection_ids => {
      :app_space       => lambda { |app| VCAP::CloudController::Models::AppSpace.make  },
      :framework       => lambda { |app| VCAP::CloudController::Models::Framework.make },
      :runtime         => lambda { |app| VCAP::CloudController::Models::Runtime.make   }
    },
    :one_to_many_collection_ids  => {
      :service_bindings   =>
       lambda { |app|
          service_binding = VCAP::CloudController::Models::ServiceBinding.make
          service_binding.service_instance.app_space = app.app_space
          service_binding
       }
    }
  }

  describe "validations" do
    let(:app_obj)   { VCAP::CloudController::Models::App.make }
    let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    describe "env" do
      it "should allow an empty environment" do
        hash = {}
        update_hash = { :environment_json => hash }

        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
        last_response.status.should == 201
      end

      it "should allow multiple variables" do
        hash = { :abc => 123, :def => "hi" }
        update_hash = { :environment_json => hash }
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
        last_response.status.should == 201
      end

      [ "VMC", "vmc", "VCAP", "vcap" ].each do |k|
        it "should not allow entries to start with #{k}" do
          hash = { :abc => 123, "#{k}_abc" => "hi" }
          update_hash = { :environment_json => hash }
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 400
          decoded_response["description"].should match /environment_json reserved_key:#{k}_abc/
        end
      end
    end
  end

  shared_examples "enumerate apps ok" do |perm_name, expected|
    describe "GET /v2/apps" do
      it "should return apps to a user that has #{perm_name} permissions" do
        get "/v2/apps", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected > 0
          guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should include(@app_a.guid)
        end

        get "/v2/apps", {}, headers_for(member_b)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected > 0
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should include(@app_b.guid)
        end
      end

      it "should not return apps to a user with the #{perm_name} permission on a different app" do
        get "/v2/apps/#{@app_b.guid}", {}, headers_for(@member_a)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "create app ok" do |perm_name|
    describe "POST /v2/app/:id" do
      it "should allow a user with the #{perm_name} permission to create an app" do
        before_count = VCAP::CloudController::Models::App.all.count
        req = {
          :name => Sham.name,
          :app_space_guid => @app_space_a.guid,
          :framework_guid => Models::Framework.make.guid,
          :runtime_guid => Models::Runtime.make.guid
        }
        post "/v2/apps", Yajl::Encoder.encode(req), json_headers(headers_for(member_a))
        last_response.status.should == 201
        VCAP::CloudController::Models::App.count.should == before_count + 1
      end

      it "should not allow a user with the #{perm_name} permission for a different app to create an app" do
        before_count = VCAP::CloudController::Models::App.all.count
        req = {
          :name => Sham.name,
          :app_space_guid => @app_space_a.guid,
          :framework_guid => Models::Framework.make.guid,
          :runtime_guid => Models::Runtime.make.guid
        }
        post "/v2/apps", Yajl::Encoder.encode(req), json_headers(headers_for(member_b))
        last_response.status.should == 403
        VCAP::CloudController::Models::App.count.should == before_count
      end
    end
  end

  shared_examples "create app fail" do |perm_name|
    describe "POST /v2/app/:id" do
      it "should not allow a user with only the #{perm_name} permission to create an app" do
        req = {
          :name => Sham.name,
          :app_space_guid => @app_space_a.guid,
          :framework_guid => Models::Framework.make.guid,
          :runtime_guid => Models::Runtime.make.guid
        }
        post "/v2/apps", Yajl::Encoder.encode(req), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify app ok" do |perm_name|
    describe "PUT /v2/apps/:id" do
      it "should allow a user with the #{perm_name} permission to modify an app" do
        put "/v2/apps/#{@app_a.guid}", Yajl::Encoder.encode(:name => "#{@app_a.name}_renamed"), json_headers(headers_for(member_a))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @app_a.guid
      end

      it "should not allow a user with the #{perm_name} permission for a different app to modify an app" do
        put "/v2/apps/#{@app_a.guid}", Yajl::Encoder.encode(:name => "#{@app_a.name}_renamed"), json_headers(headers_for(member_b))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify app fail" do |perm_name|
    describe "PUT /v2/apps/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify an app" do
        put "/v2/apps/#{@app_a.guid}", Yajl::Encoder.encode(:name => "#{@app_a.name}_renamed"), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "read app ok" do |perm_name|
    describe "GET /v2/apps/:id" do
      it "should allow a user with the #{perm_name} permission to read an app" do
        get "/v2/apps/#{@app_a.guid}", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["metadata"]["guid"].should == @app_a.guid
      end

      it "should not allow a user with the #{perm_name} permission for another app to read an app" do
        get "/v2/apps/#{@app_a.guid}", {}, headers_for(member_b)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "read app fail" do |perm_name|
    describe "GET /v2/apps/:id" do
      it "should not allow a user with only the #{perm_name} permission to read an app" do
        get "/v2/apps/#{@app_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete app ok" do |perm_name|
    describe "DELETE /v2/apps/:id" do
      it "should allow a user with the #{perm_name} permission to delete an app" do
        delete "/v2/apps/#{@app_a.guid}", {}, headers_for(member_a)
        last_response.status.should == 204
      end

      it "should not allow a user with the #{perm_name} permission for a different app to delete an app" do
        delete "/v2/apps/#{@app_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete app fail" do |perm_name|
    describe "DELETE /v2/apps/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete an app" do
        delete "/v2/apps/#{@app_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  describe "Permissions" do
    include_context "permissions"

    before do
      @app_a = VCAP::CloudController::Models::App.make(:app_space => @app_space_a)
      @app_b = VCAP::CloudController::Models::App.make(:app_space => @app_space_b)
    end

    describe "Org Level Permissions" do
      describe "OrgManager" do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @org_b_manager }

        include_examples "create app fail", "OrgManager"
        include_examples "enumerate apps ok", "OrgManager", 0
        include_examples "modify app fail", "OrgManager"
        include_examples "read app fail", "OrgManager"
        include_examples "delete app fail", "OrgManager"
      end

      describe "OrgUser" do
        let(:member_a) { @org_a_member }
        let(:member_b) { @org_b_member }

        include_examples "create app fail", "OrgUser"
        include_examples "enumerate apps ok", "OrgUser", 0
        include_examples "modify app fail", "OrgUser"
        include_examples "read app fail", "OrgUser"
        include_examples "delete app fail", "OrgUser"
      end

      describe "BillingManager" do
        let(:member_a) { @org_a_billing_manager }
        let(:member_b) { @org_b_billing_manager }

        include_examples "create app fail", "BillingManager"
        include_examples "enumerate apps ok", "BillingManager", 0
        include_examples "modify app fail", "BillingManager"
        include_examples "read app fail", "BillingManager"
        include_examples "delete app fail", "BillingManager"
      end

      describe "Auditor" do
        let(:member_a) { @org_a_auditor }
        let(:member_b) { @org_b_auditor }

        include_examples "create app fail", "BillingManager"
        include_examples "enumerate apps ok", "BillingManager", 0
        include_examples "modify app fail", "BillingManager"
        include_examples "read app fail", "BillingManager"
        include_examples "delete app fail", "BillingManager"
      end
    end

    describe "App Space Level Permissions" do
      describe "AppSpaceManager" do
        let(:member_a) { @app_space_a_manager }
        let(:member_b) { @app_space_b_manager }

        include_examples "create app fail", "AppSpaceManager"
        include_examples "enumerate apps ok", "AppSpaceManager", 0
        include_examples "modify app fail", "AppSpaceManager"
        include_examples "read app fail", "AppSpaceManager"
        include_examples "delete app fail", "AppSpaceManager"
      end

      describe "Developer" do
        let(:member_a) { @app_space_a_developer }
        let(:member_b) { @app_space_b_developer }

        include_examples "create app ok", "Developer"
        include_examples "enumerate apps ok", "Developer", 1
        include_examples "modify app ok", "Developer"
        include_examples "read app ok", "Developer"
        include_examples "delete app ok", "Developer"
      end

      describe "AppSpaceAuditor" do
        let(:member_a) { @app_space_a_auditor }
        let(:member_b) { @app_space_b_auditor }

        include_examples "create app fail", "AppSpaceAuditor"
        include_examples "enumerate apps ok", "AppSpaceAuditor", 0
        include_examples "modify app fail", "AppSpaceAuditor"
        include_examples "read app ok", "AppSpaceAuditor"
        include_examples "delete app fail", "AppSpaceAuditor"
      end
    end

    describe "CFAdmin" do
      it "should allow a user with the CFAdmin permission to enumerate all apps" do
        get "/v2/apps", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == Models::App.all.count
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should ==
          Models::App.select(:guid).collect { |o| o.guid }
      end

      it "should allow a user with the CFAdmin permission to read any app" do
        get "/v2/apps/#{@app_a.guid}", {}, headers_for(@cf_admin)
        last_response.should be_ok
      end

      it "should allow a user with the CFAdmin permission to modify any app" do
        put "/v2/apps/#{@app_a.guid}", Yajl::Encoder.encode(:name => "#{@app_a.name}_renamed"), json_headers(headers_for(@cf_admin))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @app_a.guid
      end

      it "should allow a user with the CFAdmin permission to delete an app" do
        delete "/v2/apps/#{@app_a.guid}", {}, headers_for(@cf_admin)
        last_response.status.should == 204
      end
    end
  end

  describe "quota" do
    let(:cf_admin) { Models::User.make(:admin => true) }
    let(:app_obj) { Models::App.make }

    describe "create" do
      it "should fetch a quota token" do
        should_receive_quota_call
        post "/v2/apps", Yajl::Encoder.encode(:name => Sham.name,
                                              :app_space_guid => app_obj.app_space_guid,
                                              :framework_guid => app_obj.framework_guid,
                                              :runtime_guid => app_obj.runtime_guid),
                                              headers_for(cf_admin)
        last_response.status.should == 201
      end
    end

    describe "get" do
      it "should not fetch a quota token" do
        should_not_receive_quota_call
        RestController::QuotaManager.should_not_receive(:fetch_quota_token)
        get "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
        last_response.status.should == 200
      end
    end

    describe "update" do
      it "should fetch a quota token" do
        should_receive_quota_call
        put "/v2/apps/#{app_obj.guid}",
            Yajl::Encoder.encode(:name => "#{app_obj.name}_renamed"),
            headers_for(cf_admin)
        last_response.status.should == 201
      end
    end

    describe "delete" do
      it "should fetch a quota token" do
        should_receive_quota_call
        delete "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
