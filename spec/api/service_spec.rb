# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Service do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/services",
      :model                => Models::Service,
      :basic_attributes     => [:label, :provider, :url, :description, :version, :info_url],
      :required_attributes  => [:label, :provider, :url, :description, :version],
      :unique_attributes    => [:label, :provider],
      :one_to_many_collection_ids  => {
        :service_plans => lambda { |service| Models::ServicePlan.make }
      }
    }

    shared_examples "enumerate and read service only" do |perm_name|
      include_examples "permission checks", perm_name,
        :model => Models::Service,
        :path => "/v2/services",
        :permissions_overlap => true,
        :enumerate => 7,
        :create => :not_allowed,
        :read => :allowed,
        :modify => :not_allowed,
        :delete => :not_allowed
    end

    describe "Permissions" do
      include_context "permissions"

      before(:all) do
        reset_database
        5.times do
          Models::Service.make
        end
        @obj_a = Models::Service.make
        @obj_b = Models::Service.make
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => Sham.description,
          :version => Sham.version)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:label => Sham.label)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "enumerate and read service only", "OrgManager"
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "enumerate and read service only", "OrgUser"
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "enumerate and read service only", "BillingManager"
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "enumerate and read service only", "Auditor"
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "enumerate and read service only", "SpaceManager"
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "enumerate and read service only", "Developer"
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "enumerate and read service only", "SpaceAuditor"
        end
      end
    end

    describe "get /v2/services?q=active:<t|f>" do
      let (:headers) do
        user = VCAP::CloudController::Models::User.make
        headers_for(user)
      end

      before(:all) do
        reset_database
        3.times { Models::Service.make(:active => true) }
        2.times { Models::Service.make(:active => false) }
      end

      it "should get all services" do
        get "/v2/services", {}, headers
        last_response.should be_ok
        decoded_response["total_results"].should == 5
      end

      it "should filter inactive services" do
        # Sequel stores 'true' and 'false' as 't' and 'f' in sqlite, so with
        # sqlite, instead of 'true' or 'false', the parameter must be specified
        # as 't' or 'f'. But in postgresql, either way is ok.
        get "/v2/services?q=active:t", {}, headers
        last_response.should be_ok
        decoded_response["total_results"].should == 3
      end

      it "should get inactive services" do
        get "/v2/services?q=active:f", {}, headers
        last_response.should be_ok
        decoded_response["total_results"].should == 2
      end
    end
  end
end
