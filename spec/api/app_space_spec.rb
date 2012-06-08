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
      :auditors   => lambda { |app_space| make_user_for_app_space(app_space) }
    },
    :one_to_many_collection_ids => {
      :apps  => lambda { |app_space| VCAP::CloudController::Models::App.make }
    }
  }

  shared_examples "enumerate app spaces ok" do |perm_name|
    describe "GET /v2/app_spaces" do
      it "should return app_spaces to a user that has #{perm_name} permissions" do
        get "/v2/app_spaces", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@app_space_a.guid]

        get "/v2/app_spaces", {}, headers_for(member_b)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@app_space_b.guid]
      end

      it "should not return app spaces to a user with the #{perm_name} permission on a different app space" do
        get "/v2/app_spaces/#{@app_space_b.guid}", {}, headers_for(@app_space_a_manager)
        last_response.should_not be_ok
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
    before do
      @app_space_a = VCAP::CloudController::Models::AppSpace.make
      @app_space_a_manager = make_user_for_app_space(@app_space_a)
      @app_space_a_developer = make_user_for_app_space(@app_space_a)
      @app_space_a_auditor = make_user_for_app_space(@app_space_a)
      @app_space_a.add_manager(@app_space_a_manager)
      @app_space_a.add_developer(@app_space_a_developer)
      @app_space_a.add_auditor(@app_space_a_auditor)

      @app_space_b = VCAP::CloudController::Models::AppSpace.make
      @app_space_b_manager = make_user_for_app_space(@app_space_b)
      @app_space_b_developer = make_user_for_app_space(@app_space_b)
      @app_space_b_auditor = make_user_for_app_space(@app_space_b)
      @app_space_b.add_manager(@app_space_b_manager)
      @app_space_b.add_developer(@app_space_b_developer)
      @app_space_b.add_auditor(@app_space_b_auditor)

      @cf_admin = VCAP::CloudController::Models::User.make(:admin => true)
    end

    describe "AppSpaceManager" do
      let(:member_a) { @app_space_a_manager }
      let(:member_b) { @app_space_b_manager }

      include_examples "enumerate app spaces ok", "AppSpaceManager"
      include_examples "modify app space ok", "AppSpaceManager"
      include_examples "read app space ok", "AppSpaceManager"
      include_examples "delete app space ok", "AppSpaceManager"
    end

    describe "Developer" do
      let(:member_a) { @app_space_a_developer }
      let(:member_b) { @app_space_b_developer }

      include_examples "enumerate app spaces ok", "Developer"
      include_examples "modify app space fail", "Developer"
      include_examples "read app space ok", "Developer"
      include_examples "delete app space fail", "Developer"
    end

    describe "AppSpaceAuditor" do
      let(:member_a) { @app_space_a_auditor }
      let(:member_b) { @app_space_b_auditor }

      include_examples "enumerate app spaces ok", "AppSpaceAuditor"
      include_examples "modify app space fail", "AppSpaceAuditor"
      include_examples "read app space ok", "AppSpaceAuditor"
      include_examples "delete app space fail", "AppSpaceAuditor"
    end

    describe "CFAdmin" do
      it "should allow a user with the CFAdmin permission to enumerate all app spaces" do
        get "/v2/app_spaces", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == 2
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@app_space_a.guid, @app_space_b.guid]
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
