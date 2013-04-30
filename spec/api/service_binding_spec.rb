require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServiceBinding do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/service_bindings",
      :model                => Models::ServiceBinding,
      :basic_attributes     => [:app_guid, :service_instance_guid],
      :required_attributes  => [:app_guid, :service_instance_guid],
      :unique_attributes    => [:app_guid, :service_instance_guid],
      :create_attribute     => lambda { |name|
        @space ||= Models::Space.make
        case name.to_sym
        when :app_guid
          app = Models::App.make(:space => @space)
          app.guid
        when :service_instance_guid
          service_instance = Models::ServiceInstance.make(:space => @space)
          service_instance.guid
        end
      },
      :create_attribute_reset => lambda { @space = nil }
    }

    describe "staging" do
      let(:app_obj) do
        app = Models::App.make
        fake_app_staging(app)
        app
      end

      let(:service_instance) { Models::ServiceInstance.make(:space => app_obj.space) }

      let(:admin_headers) do
        user = Models::User.make(:admin => true)
        headers_for(user)
      end

      it "should flag app for restaging when creating a binding" do
        req = Yajl::Encoder.encode(:app_guid => app_obj.guid,
                                   :service_instance_guid => service_instance.guid)

        post "/v2/service_bindings", req, json_headers(admin_headers)
        last_response.status.should == 201
        app_obj.refresh
        app_obj.needs_staging?.should be_true
      end

      it "should flag app for restaging when deleting a binding" do
        binding = Models::ServiceBinding.make(:app => app_obj, :service_instance => service_instance)
        fake_app_staging(app_obj)
        app_obj.service_bindings.should include(binding)

        delete "/v2/service_bindings/#{binding.guid}", {}, admin_headers

        last_response.status.should == 204
        app_obj.refresh
        app_obj.needs_staging?.should be_true
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @app_a = Models::App.make(:space => @space_a)
        @service_instance_a = Models::ServiceInstance.make(:space => @space_a)
        @obj_a = Models::ServiceBinding.make(:app => @app_a,
                                             :service_instance => @service_instance_a)

        @app_b = Models::App.make(:space => @space_b)
        @service_instance_b = Models::ServiceInstance.make(:space => @space_b)
        @obj_b = Models::ServiceBinding.make(:app => @app_b,
                                             :service_instance => @service_instance_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :app_guid => Models::App.make(:space => @space_a).guid,
          :service_instance_guid => Models::ServiceInstance.make(:space => @space_a).guid
        )
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode({})
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
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
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
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
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
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
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
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
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
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
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::ServiceBinding,
            :path => "/v2/service_bindings",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe "PUT /v2/service_bindings/internal/:id" do
      let(:service)          { Models::Service.make }
      let(:plan)             { Models::ServicePlan.make({ :service => service })}
      let(:service_instance) { Models::ServiceInstance.make({ :service_plan => plan })}
      let(:service_binding)  { Models::ServiceBinding.make({ :service_instance => service_instance })}
      let(:admin)            { Models::User.make({ :admin => true })}

      let(:new_configuration) {{ :plan => "100" }}
      let(:new_credentials)   {{ :name => "svcs-instance-1" }}

      let(:binding_id)       { service_binding.gateway_name }

      it "should allow access with valid token" do
        req_body = {
          :token        => service.service_auth_token.token,
          :gateway_data => new_configuration,
          :credentials  => new_credentials
        }.to_json

        put "/v2/service_bindings/internal/#{binding_id}", req_body, headers_for(admin)
        last_response.status.should == 200
      end

      it "should forbidden access with invalid token" do
        req_body = {
          :token        => "wrong_token",
          :gateway_data => new_configuration,
          :credentials  => new_credentials
        }.to_json

        put "/v2/service_bindings/internal/#{binding_id}", req_body, headers_for(admin)
        last_response.status.should == 403
      end

      it "should forbidden access with invalid request body" do
        req_body = {
          :token        => service.service_auth_token.token,
          :credentials  => new_credentials
        }.to_json

        put "/v2/service_bindings/internal/#{binding_id}", req_body, headers_for(admin)
        last_response.status.should == 400
      end
    end
  end
end
