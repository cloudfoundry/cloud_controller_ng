# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstance do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/service_instances",
      :model                => Models::ServiceInstance,
      :basic_attributes     => [:name],
      :required_attributes  => [:name, :space_guid, :service_plan_guid],
      :unique_attributes    => [:space_guid, :name],
      :ci_attributes        => :name,
      :one_to_many_collection_ids => {
        :service_bindings => lambda { |service_instance|
          make_service_binding_for_service_instance(service_instance)
        }
      },
      :create_attribute_reset => lambda {}
    }

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = Models::ServiceInstance.make(:space => @space_a)
        @obj_b = Models::ServiceInstance.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid,
          :service_plan_guid => Models::ServicePlan.make.guid
        )
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => "#{@obj_a.name}_renamed")
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
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
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::ServiceInstance,
            :path => "/v2/service_instances",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe "Quota enforcement" do
      let(:paid_quota) { Models::QuotaDefinition.make(:total_services => 0) }
      let(:free_quota_with_no_services) do
        Models::QuotaDefinition.make(:total_services => 0,
                                     :non_basic_services_allowed => false)
      end
      let(:free_quota_with_one_service) do
        Models::QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end
      let(:paid_plan) { Models::ServicePlan.make }
      let(:free_plan) { Models::ServicePlan.make(:free => true) }

      context "paid quota" do
        it "should enforce quota check on number of service instances during creation" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => paid_plan.guid)

          post("/v2/service_instances",
               req, headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /file a support ticket to request additional resources/
        end
      end

      context "free quota" do
        it "should enforce quota check on number of service instances during creation" do
          org = Models::Organization.make(:quota_definition => free_quota_with_no_services)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => free_plan.guid)

          post("/v2/service_instances",
               req, headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /login to your account and upgrade/
        end

        it "should enforce quota check on service plan type during creation" do
          org = Models::Organization.make(:quota_definition => free_quota_with_one_service)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => paid_plan.guid)

          post("/v2/service_instances",
               req, headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /paid service plans are not allowed/
        end
      end

      context 'invalid space guid' do
        it "does not raise error" do
          org = Models::Organization.make()
          space = Models::Space.make(:organization => org)
          service = Models::Service.make
          plan =  Models::ServicePlan.make(free: true)

          body = {
            "space_guid" => "bogus",
            "name"       => 'name',
            "service_plan_guid" => plan.guid
          }

          post("/v2/service_instances",
               Yajl::Encoder.encode(body),
               headers_for(make_developer_for_space(space)))
          decoded_response["description"].should =~ /invalid.*space.*/
          last_response.status.should == 400
        end
      end
    end

    describe "PUT /v2/service_instances/internal/:instance_id" do
      let(:service)          { Models::Service.make }
      let(:plan)             { Models::ServicePlan.make({ :service => service })}
      let(:service_instance) { Models::ServiceInstance.make({ :service_plan => plan })}
      let(:admin)            { Models::User.make({ :admin => true })}

      let(:new_configuration) {{ :plan => "100" }}
      let(:new_credentials)   {{ :name => "svcs-instance-1" }}

      let(:instance_id)       { service_instance.gateway_name }

      it "should allow access with valid token" do
        req_body = {
          :token        => service.service_auth_token.token,
          :gateway_data => new_configuration,
          :credentials  => new_credentials
        }.to_json

        put "/v2/service_instances/internal/#{instance_id}", req_body, headers_for(admin)
        last_response.status.should == 200
      end

      it "should forbidden access with invalid token" do
        req_body = {
          :token        => "wrong_token",
          :gateway_data => new_configuration,
          :credentials  => new_credentials
        }.to_json

        put "/v2/service_instances/internal/#{instance_id}", req_body, headers_for(admin)
        last_response.status.should == 403
      end

      it "should forbidden access with invalid request body" do
        req_body = {
          :token         => service.service_auth_token.token,
          :credentials   => new_credentials
        }.to_json

        put "/v2/service_instances/internal/#{instance_id}", req_body, headers_for(admin)
        last_response.status.should == 400
      end
    end
  end
end
