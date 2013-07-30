require "spec_helper"

module VCAP::CloudController

  describe VCAP::CloudController::ServiceBindingsController, :services, type: :controller do

    include_examples "uaa authenticated api",
      path: "/v2/service_bindings"

    include_examples "enumerating objects",
      path: "/v2/service_bindings",
      model: Models::ServiceBinding

    include_examples "reading a valid object",
      path: "/v2/service_bindings",
      model: Models::ServiceBinding,
      basic_attributes: %w(app_guid service_instance_guid)

    include_examples "operations on an invalid object",
      path: "/v2/service_bindings"

    include_examples "deleting a valid object",
      path: "/v2/service_bindings",
      model: Models::ServiceBinding,
      one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {}

    include_examples "creating and updating",
      path: "/v2/service_bindings",
      model: Models::ServiceBinding,
      required_attributes: %w(app_guid service_instance_guid),
      unique_attributes: %w(app_guid service_instance_guid),
      extra_attributes: {binding_options: ->{Sham.binding_options}},
      create_attribute: lambda { |name|
        @space ||= Models::Space.make
        case name.to_sym
          when :app_guid
            app = Models::App.make(space: @space)
            app.guid
          when :service_instance_guid
            service_instance = Models::ManagedServiceInstance.make(space: @space)
            service_instance.guid
        end
      },
      create_attribute_reset: lambda { @space = nil }

    describe "staging" do
      let(:app_obj) do
        app = Models::App.make
        app.state = "STARTED"
        app.instances = 1
        fake_app_staging(app)
        app
      end

      let(:service_instance) { Models::ManagedServiceInstance.make(:space => app_obj.space) }

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
        @service_instance_a = Models::ManagedServiceInstance.make(:space => @space_a)
        @obj_a = Models::ServiceBinding.make(:app => @app_a,
                                             :service_instance => @service_instance_a)

        @app_b = Models::App.make(:space => @space_b)
        @service_instance_b = Models::ManagedServiceInstance.make(:space => @space_b)
        @obj_b = Models::ServiceBinding.make(:app => @app_b,
                                             :service_instance => @service_instance_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :app_guid => Models::App.make(:space => @space_a).guid,
          :service_instance_guid => Models::ManagedServiceInstance.make(:space => @space_a).guid
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

    describe 'for provided instances' do
      let(:space) { Models::Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:application) { Models::App.make(:space => space) }
      let(:service_instance) { Models::UserProvidedServiceInstance.make(:space => space) }
      let(:params) do
        {
          "app_guid" => application.guid,
          "service_instance_guid" => service_instance.guid
        }
      end

      it 'creates a service binding' do
        post "/v2/service_bindings", params.to_json, headers_for(developer)
        last_response.status.should == 201
      end

      it 'honors the binding options' do
        binding_options = Sham.binding_options
        body =  params.merge("binding_options" => binding_options).to_json
        post "/v2/service_bindings", body, headers_for(developer)
        Models::ServiceBinding.last.binding_options.should == binding_options
      end
    end
  end
end
