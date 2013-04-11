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
      @org_a.add_user(@org_a_manager)
      @org_a.add_user(@org_a_member)
      @org_a.add_user(@org_a_billing_manager)
      @org_a.add_user(@org_a_auditor)
      @org_a.add_manager(@org_a_manager)
      @org_a.add_billing_manager(@org_a_billing_manager)
      @org_a.add_auditor(@org_a_auditor)

      @space_a = Models::Space.make(:organization => @org_a)
      @space_a_manager = make_user_for_space(@space_a)
      @space_a_developer = make_user_for_space(@space_a)
      @space_a_auditor = make_user_for_space(@space_a)
      @space_a.add_manager(@space_a_manager)
      @space_a.add_developer(@space_a_developer)
      @space_a.add_auditor(@space_a_auditor)

      @org_b = Models::Organization.make
      @org_b_manager = Models::User.make
      @org_b_member = Models::User.make
      @org_b_billing_manager = Models::User.make
      @org_b_auditor = Models::User.make
      @org_b.add_user(@org_b_manager)
      @org_b.add_user(@org_b_member)
      @org_b.add_user(@org_b_billing_manager)
      @org_b.add_user(@org_b_auditor)
      @org_b.add_manager(@org_b_manager)
      @org_b.add_billing_manager(@org_b_billing_manager)
      @org_b.add_auditor(@org_b_auditor)

      @space_b = Models::Space.make(:organization => @org_b)
      @space_b_manager = make_user_for_space(@space_b)
      @space_b_developer = make_user_for_space(@space_b)
      @space_b_auditor = make_user_for_space(@space_b)
      @space_b.add_manager(@space_b_manager)
      @space_b.add_developer(@space_b_developer)
      @space_b.add_auditor(@space_b_auditor)

      @cf_admin = Models::User.make(:admin => true)
    end
  end

  shared_examples "permission enumeration" do |perm_name, model, name, path, path_suffix, expected, perms_overlap|
    describe "GET #{path}" do
      it "should return #{expected} #{name.pluralize} to a user that has #{perm_name} permissions" do
        get path, {}, headers_a
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
        if respond_to?(:enumeration_expectation_a)
          guids.sort.should == enumeration_expectation_a.map(&:guid).sort
        else
          guids.should include(@obj_a.guid) if expected > 0
        end

        get path, {}, headers_b
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
        if respond_to?(:enumeration_expectation_b)
          expect(guids.sort).to eq enumeration_expectation_b.map(&:guid).sort
        else
          guids.should include(@obj_b.guid) if expected > 0
        end
      end

      unless perms_overlap
        it "should not return a #{name} to a user with the #{perm_name} permission on a different #{name}" do
          get "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_b
          last_response.should_not be_ok
        end
      end
    end
  end

  shared_examples "permission create allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "POST #{path}" do
      it "should allow a user with the #{perm_name} permission to create a #{name}" do
        expect {
          post path, creation_req_for_a, json_headers(headers_a)
          last_response.status.should == 201
        }.to change { model.count }.by(1)
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different service instance to create a service instance" do
          expect {
            post path, creation_req_for_a, json_headers(headers_b)
            last_response.status.should == 403
          }.to_not change { model.count }
        end
      end
    end
  end

  shared_examples "permission create not_allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "POST #{path}" do
      context "when the user has only the #{perm_name} permissions" do
        it "should return a forbidden response" do
          post path, creation_req_for_a, json_headers(headers_a)
          last_response.status.should == 403
        end

        it "should not create a #{name}" do
          expect {
            post path, creation_req_for_a, json_headers(headers_a)
          }.to_not change { model.count }
        end
      end
    end
  end

  shared_examples "permission modify allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "PUT #{path}/:id" do
      it "should allow a user with the #{perm_name} permission to modify a #{name}" do
        put "#{path}/#{@obj_a.guid}#{path_suffix}", update_req_for_a, json_headers(headers_a)
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @obj_a.guid
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different #{name} to modify a #{name}" do
          put "#{path}/#{@obj_a.guid}#{path_suffix}", update_req_for_a, json_headers(headers_b)
          last_response.status.should == 403
        end
      end
    end
  end

  shared_examples "permission modify not_allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "PUT /v2/service_instances/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify a #{name}" do
        put "#{path}/#{@obj_a.guid}#{path_suffix}", update_req_for_a, json_headers(headers_a)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission read not_allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "GET #{path}/:id" do
      it "should not allow a user with only the #{perm_name} permission to read a #{name}" do
        get "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_a
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission read allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "GET #{path}/:id" do
      it "should allow a user with the #{perm_name} permission to read a #{name}" do
        get "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_a
        last_response.status.should == 200

        returned_guid = (path_suffix == "/summary") ? decoded_response["guid"] : decoded_response["metadata"]["guid"]
        returned_guid.should == @obj_a.guid
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for another #{name} to read a #{name}" do
          get "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_b
          last_response.status.should == 403
        end
      end
    end
  end

  shared_examples "permission delete allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "DELETE /v2/apps/:id" do
      it "should allow a user with the #{perm_name} permission to delete a #{name}" do
        delete "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_a
        last_response.status.should == 204
      end

      unless perms_overlap
        it "should not allow a user with the #{perm_name} permission for a different #{name} to delete a #{name}" do
          delete "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_b
          last_response.status.should == 403
        end
      end
    end
  end

  shared_examples "permission delete not_allowed" do |perm_name, model, name, path, path_suffix, perms_overlap|
    describe "DELETE #{path}/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete a #{name}" do
        delete "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_a
        last_response.status.should == 403
      end
    end
  end

  shared_examples "permission checks" do |perm_name, opts|
    model = opts[:model]
    name = model.name.split("::").last.underscore.gsub("_", " ")

    path = opts[:path]
    path_suffix = opts[:path_suffix]
    perms_overlap = opts[:permissions_overlap]

    include_examples "permission enumeration",
      perm_name, model, name, path, path_suffix, opts[:enumerate], perms_overlap

    [:create, :read, :modify, :delete].each do |op|
      include_examples "permission #{op} #{opts[op]}", perm_name, model, name, path, path_suffix, perms_overlap
    end
  end

  shared_examples "read permission check" do |perm_name, opts|
    model = opts[:model]
    name = model.name.split("::").last.underscore.gsub("_", " ")

    path = opts[:path]
    path_suffix = opts[:path_suffix]

    include_examples "permission read #{opts[:allowed] ? "allowed" : "not_allowed"}",
      perm_name, model, name, path, path_suffix, false
  end
end
