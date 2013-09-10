require "spec_helper"

module VCAP::CloudController

  describe VCAP::CloudController::ServiceBindingsController, :services, type: :controller do

    include_examples "uaa authenticated api",
      path: "/v2/service_bindings"

    include_examples "enumerating objects",
      path: "/v2/service_bindings",
      model: ServiceBinding

    include_examples "reading a valid object",
      path: "/v2/service_bindings",
      model: ServiceBinding,
      basic_attributes: %w(app_guid service_instance_guid)

    include_examples "operations on an invalid object",
      path: "/v2/service_bindings"

    include_examples "deleting a valid object",
      path: "/v2/service_bindings",
      model: ServiceBinding,
      one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {}

    include_examples "creating and updating",
      path: "/v2/service_bindings",
      model: ServiceBinding,
      required_attributes: %w(app_guid service_instance_guid),
      unique_attributes: %w(app_guid service_instance_guid),
      extra_attributes: {binding_options: ->{Sham.binding_options}},
      create_attribute: lambda { |name|
        @space ||= Space.make
        case name.to_sym
          when :app_guid
            app = App.make(space: @space)
            app.guid
          when :service_instance_guid
            service_instance = ManagedServiceInstance.make(space: @space)
            service_instance.guid
        end
      },
      create_attribute_reset: lambda { @space = nil }

    describe "staging" do
      let(:app_obj) do
        app = App.make
        app.state = "STARTED"
        app.instances = 1
        fake_app_staging(app)
        app
      end

      let(:service_instance) { ManagedServiceInstance.make(:space => app_obj.space) }

      it "should flag app for restaging when creating a binding" do
        req = Yajl::Encoder.encode(:app_guid => app_obj.guid,
                                   :service_instance_guid => service_instance.guid)

        post "/v2/service_bindings", req, json_headers(admin_headers)
        last_response.status.should == 201
        app_obj.refresh
        app_obj.needs_staging?.should be_true
      end

      it "should flag app for restaging when deleting a binding" do
        binding = ServiceBinding.make(:app => app_obj, :service_instance => service_instance)
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
        @app_a = App.make(:space => @space_a)
        @service_instance_a = ManagedServiceInstance.make(:space => @space_a)
        @obj_a = ServiceBinding.make(:app => @app_a,
                                             :service_instance => @service_instance_a)

        @app_b = App.make(:space => @space_b)
        @service_instance_b = ManagedServiceInstance.make(:space => @space_b)
        @obj_b = ServiceBinding.make(:app => @app_b,
                                             :service_instance => @service_instance_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :app_guid => App.make(:space => @space_a).guid,
          :service_instance_guid => ManagedServiceInstance.make(:space => @space_a).guid
        )
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode({})
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission enumeration", "SpaceManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 1
        end
      end
    end

    describe 'for provided instances' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:application) { App.make(:space => space) }
      let(:service_instance) { UserProvidedServiceInstance.make(:space => space) }
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
        ServiceBinding.last.binding_options.should == binding_options
      end
    end

    describe "creating a binding for a service that does syslog drains" do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }

      it "stores the syslog_drain_url" do
        instance = ManagedServiceInstance.make(:space => space)
        app = App.make(:space => space)

        post("/v2/service_bindings",
             {"app_guid" => app.guid,
             "service_instance_guid" => instance.guid}.to_json,
             headers_for(developer))

        last_response.status.should == 201
        ServiceBinding.last.syslog_drain_url.should == "syslog://example.com:1234"
      end
    end
  end
end
