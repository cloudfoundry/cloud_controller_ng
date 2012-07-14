# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

module VCAP::CloudController::ApiSpecHelper
  shared_context "permissions" do
    let(:headers_a) { headers_for(member_a) }
    let(:headers_b) { headers_for(member_b) }

    before do
      @org_a = Models::Organization.make
      @org_a_manager = Models::User.make
      @org_a_member = Models::User.make
      @org_a_billing_manager = Models::User.make
      @org_a_auditor = Models::User.make
      @org_a.add_manager(@org_a_manager)
      @org_a.add_user(@org_a_member)
      @org_a.add_billing_manager(@org_a_billing_manager)
      @org_a.add_auditor(@org_a_auditor)

      @app_space_a = Models::AppSpace.make(:organization => @org_a)
      @app_space_a_manager = make_user_for_app_space(@app_space_a)
      @app_space_a_developer = make_user_for_app_space(@app_space_a)
      @app_space_a_auditor = make_user_for_app_space(@app_space_a)
      @app_space_a.add_manager(@app_space_a_manager)
      @app_space_a.add_developer(@app_space_a_developer)
      @app_space_a.add_auditor(@app_space_a_auditor)

      @org_b = Models::Organization.make
      @org_b_manager = Models::User.make
      @org_b_member = Models::User.make
      @org_b_billing_manager = Models::User.make
      @org_b_auditor = Models::User.make
      @org_b.add_manager(@org_b_manager)
      @org_b.add_user(@org_b_member)
      @org_b.add_billing_manager(@org_b_billing_manager)
      @org_b.add_auditor(@org_b_auditor)

      @app_space_b = Models::AppSpace.make(:organization => @org_b)
      @app_space_b_manager = make_user_for_app_space(@app_space_b)
      @app_space_b_developer = make_user_for_app_space(@app_space_b)
      @app_space_b_auditor = make_user_for_app_space(@app_space_b)
      @app_space_b.add_manager(@app_space_b_manager)
      @app_space_b.add_developer(@app_space_b_developer)
      @app_space_b.add_auditor(@app_space_b_auditor)

      @cf_admin = Models::User.make(:admin => true)
    end
  end

  shared_examples "permission enumeration" do |perm_name, model, name, path, expected, perms_overlap|
    describe "GET #{path}" do
      it "should return #{name} to a user that has #{perm_name} permissions" do
        get path, {}, headers_a
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected > 0
          guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
          guids.should include(@obj_a.guid)
        end

        get path, {}, headers_b
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected > 0
          guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
          guids.should include(@obj_b.guid)
        end
      end

      unless perms_overlap
        it "should not return a #{name} to a user with the #{perm_name} permission on a different #{name}" do
          get "#{path}/#{@obj_a.guid}", {}, headers_b
          last_response.should_not be_ok
        end
      end
    end
  end

  shared_examples "permission create allowed" do |perm_name, model, name, path, perms_overlap|
    describe "POST #{path}" do
      it "should allow a user with the #{perm_name} permission to create a #{name}" do
        before_count = model.count
        post path, creation_req_for_a, json_headers(headers_a)
        last_response.status.should == 201
        model.count.should == before_count + 1
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different service instance to create a service instance" do
          before_count = model.count
          post path, creation_req_for_a, json_headers(headers_b)
          last_response.status.should == 403
          model.count.should == before_count
        end
      end
    end
  end

  shared_examples "permission create not_allowed" do |perm_name, model, name, path|
    describe "POST #{path}" do
      it "should not allow a user with only the #{perm_name} permission to create a #{name}" do
        post path, creation_req_for_a, json_headers(headers_a)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission modify allowed" do |perm_name, model, name, path, perms_overlap|
    describe "PUT #{path}/:id" do
      it "should allow a user with the #{perm_name} permission to modify a #{name}" do
        put "#{path}/#{@obj_a.guid}", update_req_for_a, json_headers(headers_a)
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @obj_a.guid
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different #{name} to modify a #{name}" do
          put "#{path}/#{@obj_a.guid}", update_req_for_a, json_headers(headers_b)
          last_response.status.should == 403
        end
      end
    end
  end

  shared_examples "permission modify not_allowed" do |perm_name, model, name, path|
    describe "PUT /v2/service_instances/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify a #{name}" do
        put "#{path}/#{@obj_a.guid}", update_req_for_a, json_headers(headers_a)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission read not_allowed" do |perm_name, model, name, path|
    describe "GET #{path}/:id" do
      it "should not allow a user with only the #{perm_name} permission to read a #{name}" do
        get "#{path}/#{@obj_a.guid}", {}, headers_a
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission read allowed" do |perm_name, model, name, path, perms_overlap|
    describe "GET #{path}/:id" do
      it "should allow a user with the #{perm_name} permission to read a #{name}" do
        get "#{path}/#{@obj_a.guid}", {}, headers_a
        last_response.should be_ok
        decoded_response["metadata"]["guid"].should == @obj_a.guid
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for another #{name} to read a #{name}" do
          get "#{path}/#{@obj_a.guid}", {}, headers_b
          last_response.should_not be_ok
        end
      end
    end
  end

  shared_examples "permission delete allowed" do |perm_name, model, name, path, perms_overlap|
    describe "DELETE /v2/apps/:id" do
      it "should allow a user with the #{perm_name} permission to delete a #{name}" do
        delete "#{path}/#{@obj_a.guid}", {}, headers_a
        last_response.status.should == 204
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different #{name} to delete a #{name}" do
          delete "#{path}/#{@obj_a.guid}", {}, headers_b
          last_response.status.should == 403
        end
      end
    end
  end

  shared_examples "permission delete not_allowed" do |perm_name, model, name, path|
    describe "DELETE #{path}/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete a #{name}" do
        delete "#{path}/#{@obj_a.guid}", {}, headers_a
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission checks" do |perm_name, opts|
    model = opts[:model]
    path = opts[:path]
    name = model.name.split("::").last.underscore.gsub("_", " ")
    perms_overlap = opts[:permissions_overlap]

    include_examples "permission enumeration",
      perm_name, model, name, path, opts[:enumerate], perms_overlap

    [:create, :read, :modify, :delete].each do |op|
      include_examples "permission #{op} #{opts[op]}", perm_name, model, name, path, perms_overlap
    end
  end
end
