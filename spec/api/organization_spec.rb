# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Organization do
  let(:org)   { VCAP::CloudController::Models::Organization.make }

  it_behaves_like "a CloudController API", {
    :path                => '/v2/organizations',
    :model               => VCAP::CloudController::Models::Organization,
    :basic_attributes    => :name,
    :required_attributes => :name,
    :unique_attributes   => :name,
    :many_to_many_collection_ids => {
      :users    => lambda { |org| VCAP::CloudController::Models::User.make },
      :managers => lambda { |org| VCAP::CloudController::Models::User.make }
    },
    :one_to_many_collection_ids  => {
      :app_spaces => lambda { |org| VCAP::CloudController::Models::AppSpace.make }
    }
  }

  describe "Permissions" do
    before do
      @org_a = VCAP::CloudController::Models::Organization.make
      @org_a_manager = VCAP::CloudController::Models::User.make
      @org_a.add_manager(@org_a_manager)

      @org_b = VCAP::CloudController::Models::Organization.make
      @org_b_manager = VCAP::CloudController::Models::User.make
      @org_b.add_manager(@org_b_manager)

      @cf_admin = VCAP::CloudController::Models::User.make(:admin => true)
    end

    describe "org manager" do
      it "should allow an org manager to enumerate only their orgs" do
        get "/v2/organizations", {}, headers_for(@org_a_manager)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["id"] }.should == [@org_a.id]

        get "/v2/organizations", {}, headers_for(@org_b_manager)
        last_response.should be_ok
        decoded_response["total_results"].should == 1
        decoded_response["resources"].map { |o| o["metadata"]["id"] }.should == [@org_b.id]
      end

      it "should allow an org manager to read an org that they own" do
        get "/v2/organizations/#{@org_a.id}", {}, headers_for(@org_a_manager)
        last_response.should be_ok
        decoded_response["metadata"]["id"].should == @org_a.id
      end

      it "should not allow an org manager to read an org that they don't own" do
        get "/v2/organizations/#{@org_b.id}", {}, headers_for(@org_a_manager)
        last_response.should_not be_ok
      end

      it "should allow an org manager to modify an org that they own" do
        put "/v2/organizations/#{@org_a.id}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(@org_a_manager))
        last_response.status.should == 201
        decoded_response["metadata"]["id"].should == @org_a.id
      end

      it "should allow an org manager to delete an org that they own" do
        delete "/v2/organizations/#{@org_a.id}", {}, headers_for(@org_a_manager)
        last_response.status.should == 204
      end

      it "should not allow an org manager to delete an org that they own" do
        delete "/v2/organizations/#{@org_b.id}", {}, headers_for(@org_a_manager)
        last_response.status.should == 403
      end
    end

    describe "cf admin" do
      it "should allow a cf admin to enumerate all orgs" do
        get "/v2/organizations", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == 2
        decoded_response["resources"].map { |o| o["metadata"]["id"] }.should == [@org_a.id, @org_b.id]
      end

      it "should allow a cf admin to read any org" do
        get "/v2/organizations/#{@org_a.id}", {}, headers_for(@cf_admin)
        last_response.should be_ok
      end

      it "should allow a cf admin to modify any org" do
        put "/v2/organizations/#{@org_a.id}", Yajl::Encoder.encode({ :name => "#{@org_a.name}_renamed" }), json_headers(headers_for(@cf_admin))
        last_response.status.should == 201
        decoded_response["metadata"]["id"].should == @org_a.id
      end

      it "should allow a cf admin to delete an org" do
        delete "/v2/organizations/#{@org_a.id}", {}, headers_for(@cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
