# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Domain do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/domains",
    :model                => VCAP::CloudController::Models::Domain,
    :basic_attributes     => [:name, :organization_guid],
    :required_attributes  => [:name, :organization_guid],
    :unique_attributes    => :name
  }

  shared_examples "create domain ok" do |perm_name|
    describe "POST /v2/domains/:id" do
      it "should allow a user with the #{perm_name} permission to create a domain" do
        post "/v2/domains", Yajl::Encoder.encode({ :name => "domain_a.com", :organization_guid => @org_a.guid }), json_headers(headers_for(member_a))
        last_response.status.should == 201
      end

      it "should not allow a user with the #{perm_name} permission on a different domain to modify a domain" do
        post "/v2/domains", Yajl::Encoder.encode({ :name => "domain_b.com", :organization_guid => @org_a.guid }), json_headers(headers_for(member_b))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "create domain fail" do |perm_name|
    describe "POST /v2/domains" do
      it "should not allow a user with only the #{perm_name} permission to create a domain" do
        post "/v2/domains", Yajl::Encoder.encode({ :name => "domain.com", :organization_guid => @org_a.guid }), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "enumerate domains ok" do |perm_name, expected|
    expected ||= 1
    describe "GET /v2/domains" do
      it "should return #{expected} domains to a user that has #{perm_name} permissions" do
        get "/v2/domains", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected == 1
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@domain_a.guid]
        end

        get "/v2/domains", {}, headers_for(member_b)
        last_response.should be_ok
        decoded_response["total_results"].should == expected
        if expected == 1
          decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@domain_b.guid]
        end
      end

      it "should not return app spaces to a user with the #{perm_name} permission on a different app space" do
        get "/v2/domains/#{@domain_b.guid}", {}, headers_for(member_a)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "modify domain ok" do |perm_name|
    describe "PUT /v2/domains/:id" do
      it "should allow a user with the #{perm_name} permission to modify a domain" do
        put "/v2/domains/#{@domain_a.guid}", Yajl::Encoder.encode({ :name => "#{@domain_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @domain_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on a different domain to modify a domain" do
        put "/v2/domains/#{@domain_a.guid}", Yajl::Encoder.encode({ :name => "#{@domain_a.name}_renamed" }), json_headers(headers_for(member_b))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "modify domain fail" do |perm_name|
    describe "PUT /v2/domains/:id" do
      it "should not allow a user with only the #{perm_name} permission to modify a domain" do
        put "/v2/domains/#{@domain_a.guid}", Yajl::Encoder.encode({ :name => "#{@domain_a.name}_renamed" }), json_headers(headers_for(member_a))
        last_response.status.should == 403
      end
    end
  end

  shared_examples "read domain ok" do |perm_name|
    describe "GET /v2/domains/:id" do
      it "should allow a user with the #{perm_name} permission to read a domain" do
        get "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_a)
        last_response.should be_ok
        decoded_response["metadata"]["guid"].should == @domain_a.guid
      end

      it "should not allow a user with the #{perm_name} permission on another domain to read a domain" do
        get "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_b)
        last_response.should_not be_ok
      end
    end
  end

  shared_examples "read domain fail" do |perm_name|
    describe "GET /v2/domains/:id" do
      it "should not allow a user with only the #{perm_name} permission to read a domain" do
        get "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete domain ok" do |perm_name|
    before do
      @app_space_a.destroy
      @app_space_b.destroy
    end

    describe "DELETE /v2/domains/:id" do
      it "should allow a user with the #{perm_name} permission to delete a domain" do
        delete "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_a)
        last_response.status.should == 204
      end

      it "should not allow a user with the #{perm_name} permission on a different domain to delete a domain" do
        delete "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  shared_examples "delete domain fail" do |perm_name|
    describe "DELETE /v2/domains/:id" do
      it "should not allow a user with only the #{perm_name} permission to delete a domain" do
        delete "/v2/domains/#{@domain_a.guid}", {}, headers_for(member_b)
        last_response.status.should == 403
      end
    end
  end

  describe "Permissions" do
    include_context "permissions"

    before do
      @domain_a = VCAP::CloudController::Models::Domain.make(:organization => @org_a)
      @app_space_a.add_domain(@domain_a)

      @domain_b = VCAP::CloudController::Models::Domain.make(:organization => @org_b)
      @app_space_b.add_domain(@domain_b)
    end

    describe "Org Level Permissions" do
      describe "OrgManager" do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @org_b_manager }

        include_examples "create domain ok", "OrgManager"
        include_examples "enumerate domains ok", "OrgManager"
        include_examples "modify domain ok", "OrgManager"
        include_examples "read domain ok", "OrgManager"
        include_examples "delete domain ok", "OrgManager"
      end

      describe "OrgUser" do
        let(:member_a) { @org_a_member }
        let(:member_b) { @org_b_member }

        include_examples "create domain fail", "OrgUser"
        include_examples "enumerate domains ok", "OrgUser", 0
        include_examples "modify domain fail", "OrgUser"
        include_examples "read domain fail", "OrgUser"
        include_examples "delete domain fail", "OrgUser"
      end

      describe "BillingManager" do
        let(:member_a) { @org_a_billing_manager }
        let(:member_b) { @org_b_billing_manager }

        include_examples "create domain fail", "BillingManager"
        include_examples "enumerate domains ok", "BillingManager", 0
        include_examples "modify domain fail", "BillingManager"
        include_examples "read domain fail", "BillingManager"
        include_examples "delete domain fail", "BillingManager"
      end

      describe "Auditor" do
        let(:member_a) { @org_a_auditor }
        let(:member_b) { @org_b_auditor }

        include_examples "create domain fail", "Auditor"
        include_examples "enumerate domains ok", "Auditor", 0
        include_examples "modify domain fail", "Auditor"
        include_examples "read domain fail", "Auditor"
        include_examples "delete domain fail", "Auditor"
      end
    end

    describe "App Space Level Permissions" do
      describe "AppSpaceManager" do
        let(:member_a) { @app_space_a_manager }
        let(:member_b) { @app_space_b_manager }

        include_examples "create domain fail", "AppSpaceManager"
        include_examples "enumerate domains ok", "AppSpaceManager", 0
        include_examples "modify domain fail", "AppSpaceManager"
        include_examples "read domain ok", "AppSpaceManager"
        include_examples "delete domain fail", "AppSpaceManager"
      end

      describe "Developer" do
        let(:member_a) { @app_space_a_developer }
        let(:member_b) { @app_space_b_developer }

        include_examples "create domain fail", "Developer"
        include_examples "enumerate domains ok", "Developer", 0
        include_examples "modify domain fail", "Developer"
        include_examples "read domain ok", "Developer"
        include_examples "delete domain fail", "Developer"
      end

      describe "AppSpaceAuditor" do
        let(:member_a) { @app_space_a_auditor }
        let(:member_b) { @app_space_b_auditor }

        include_examples "create domain fail", "AppSpaceAuditor"
        include_examples "enumerate domains ok", "AppSpaceAuditor", 0
        include_examples "modify domain fail", "AppSpaceAuditor"
        include_examples "read domain ok", "AppSpaceAuditor"
        include_examples "delete domain fail", "AppSpaceAuditor"
      end
    end

    describe "CFAdmin" do
      it "should allow a user with the CFAdmin permission to enumerate all domains" do
        get "/v2/domains", {}, headers_for(@cf_admin)
        last_response.should be_ok
        decoded_response["total_results"].should == 2
        decoded_response["resources"].map { |o| o["metadata"]["guid"] }.should == [@domain_a.guid, @domain_b.guid]
      end

      it "should allow a user with the CFAdmin permission to read any domain" do
        get "/v2/domains/#{@domain_a.guid}", {}, headers_for(@cf_admin)
        last_response.should be_ok
      end

      it "should allow a user with the CFAdmin permission to modify any domain" do
        put "/v2/domains/#{@domain_a.guid}", Yajl::Encoder.encode({ :name => "#{@domain_a.name}_renamed" }), json_headers(headers_for(@cf_admin))
        last_response.status.should == 201
        decoded_response["metadata"]["guid"].should == @domain_a.guid
      end

      it "should allow a user with the CFAdmin permission to delete a domain" do
        @app_space_a.destroy
        @app_space_b.destroy
        delete "/v2/domains/#{@domain_a.guid}", {}, headers_for(@cf_admin)
        last_response.status.should == 204
      end
    end
  end
end
