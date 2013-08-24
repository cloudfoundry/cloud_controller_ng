require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancesController, :services, type: :controller do
    include_examples "uaa authenticated api", path: "/v2/service_instances"
    include_examples "enumerating objects", path: "/v2/service_instances", model: Models::ManagedServiceInstance
    include_examples "reading a valid object", path: "/v2/service_instances", model: Models::ManagedServiceInstance, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/service_instances"
    include_examples "creating and updating", path: "/v2/service_instances", model: Models::ManagedServiceInstance, required_attributes: %w(name space_guid service_plan_guid), unique_attributes: %w(space_guid name)
    include_examples "deleting a valid object", path: "/v2/service_instances", model: Models::ManagedServiceInstance,
                     one_to_many_collection_ids: {
                       :service_bindings => lambda { |service_instance|
                         make_service_binding_for_service_instance(service_instance)
                       }
                     },
                     one_to_many_collection_ids_without_url: {}
    include_examples "collection operations", path: "/v2/service_instances", model: Models::ManagedServiceInstance,
                     one_to_many_collection_ids: {
                       service_bindings: lambda { |service_instance| make_service_binding_for_service_instance(service_instance) }
                     },
                     many_to_one_collection_ids: {},
                     many_to_many_collection_ids: {}

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = Models::ManagedServiceInstance.make(:space => @space_a)
        @obj_b = Models::ManagedServiceInstance.make(:space => @space_b)
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

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples "permission enumeration", user_role,
                           :name => 'managed service instance',
                           :path => "/v2/service_instances",
                           :enumerate => 0
        end
      end

      describe "Org Level Permissions" do
        user_sees_empty_enumerate("OrgManager",     :@org_a_manager,         :@org_b_manager)
        user_sees_empty_enumerate("OrgUser",        :@org_a_member,          :@org_b_member)
        user_sees_empty_enumerate("BillingManager", :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate("Auditor",        :@org_a_auditor,         :@org_b_auditor)
      end

      describe "App Space Level Permissions" do
        user_sees_empty_enumerate("SpaceManager", :@space_a_manager, :@space_b_manager)

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
                           :name => 'managed service instance',
                           :path => "/v2/service_instances",
                           :enumerate => 1
        end

        describe "private plans" do
          let!(:unprivileged_organization) { Models::Organization.make }
          let!(:private_plan) { Models::ServicePlan.make(public: false) }
          let!(:unprivileged_space) { Models::Space.make(organization: unprivileged_organization) }
          let!(:developer) { make_developer_for_space(unprivileged_space) }

          describe "a user who does not belong to a privileged organization" do
            it "does not allow a user to create a service instance" do
              payload = Yajl::Encoder.encode(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))

              last_response.status.should == 403
              Yajl::Parser.parse(last_response.body)['description'].should == VCAP::CloudController::Errors::NotAuthorized.new.message
            end
          end

          describe "a user who belongs to a privileged organization" do
            let!(:privileged_organization) do
              Models::Organization.make.tap do |org|
                Models::ServicePlanVisibility.create(
                  organization: org,
                  service_plan: private_plan
                )
              end
            end
            let!(:privileged_space) { Models::Space.make(organization: privileged_organization) }

            before do
              developer.add_organization(privileged_organization)
              privileged_space.add_developer(developer)
            end

            it "allows user to create a service instance in a privileged organization" do
              payload = Yajl::Encoder.encode(
                'space_guid' => privileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))
              last_response.status.should == 201
            end

            it "does not allow a user to create a service instance in an unprivileged organization" do
              payload = Yajl::Encoder.encode(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))

              last_response.status.should == 403
              Yajl::Parser.parse(last_response.body)['description'].should == VCAP::CloudController::Errors::ServiceInstanceOrganizationNotAuthorized.new.message
            end
          end
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
                           :name => 'managed service instance',
                           :path => "/v2/service_instances",
                           :enumerate => 0
        end
      end
    end

    describe 'POST', '/v2/service_instance' do
      context 'creating a service instance with a name over 50 characters' do
        let(:space) { Models::Space.make }
        let(:plan) { Models::ServicePlan.make }
        let(:developer) { make_developer_for_space(space) }
        let(:very_long_name) { 's' * 51 }

        it "returns an error if the service instance name is over 50 characters" do
          req = Yajl::Encoder.encode(:name => very_long_name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => plan.guid)

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /service instance name.*limited to 50 characters/
        end
      end
    end

    describe 'GET', '/v2/service_instances' do
      let(:space) { Models::Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:service_instance) {Models::ManagedServiceInstance.make}

      it "shows the dashboard_url if there is" do
        service_instance.update(dashboard_url: 'http://dashboard.io')
        get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
        decoded_response.fetch('entity').fetch('dashboard_url').should == 'http://dashboard.io'
      end

      context "filtering" do
        let(:first_found_instance) { decoded_response.fetch('resources').first }

        it 'allows filtering by gateway_name' do
          get "v2/service_instances?q=gateway_name:#{service_instance.gateway_name}", {}, admin_headers
          last_response.status.should == 200
          first_found_instance.fetch('metadata').fetch('guid').should == service_instance.guid
        end

        it 'allows filtering by name' do
          get "v2/service_instances?q=name:#{service_instance.name}", {}, admin_headers
          last_response.status.should == 200
          first_found_instance.fetch('entity').fetch('name').should == service_instance.name
        end

        it 'allows filtering by space_guid' do
          get "v2/service_instances?q=space_guid:#{service_instance.space_guid}", {}, admin_headers
          last_response.status.should == 200
          first_found_instance.fetch('entity').fetch('space_guid').should == service_instance.space_guid
        end

        it 'allows filtering by service_plan_guid' do
          get "v2/service_instances?q=service_plan_guid:#{service_instance.service_plan_guid}", {}, admin_headers
          last_response.status.should == 200
          first_found_instance.fetch('entity').fetch('service_plan_guid').should == service_instance.service_plan_guid
        end
      end
    end

    describe 'GET', '/v2/service_instances/:service_instance_guid' do
      context 'with a managed service instance' do
        let(:service_instance) { Models::ManagedServiceInstance.make }

        it "returns the service instance with the given guid" do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          last_response.status.should == 200
          decoded_response.fetch('metadata').fetch('guid').should == service_instance.guid
        end
      end

      context 'with a user provided service instance' do
        let(:service_instance) { Models::UserProvidedServiceInstance.make }

        it "returns the service instance with the given guid" do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          last_response.status.should == 200
          decoded_response.fetch('metadata').fetch('guid').should == service_instance.guid
        end
      end
    end

    describe 'DELETE', '/v2/service_instances/:service_instance_guid' do
      context 'with a managed service instance' do
        let!(:service_instance) { Models::ManagedServiceInstance.make }

        it "deletes the service instance with the given guid" do
          expect {
            delete "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(Models::ServiceInstance, :count).by(-1)
          last_response.status.should == 204
          Models::ServiceInstance.find(:guid => service_instance.guid).should be_nil
        end
      end

      context 'with a user provided service instance' do
        let!(:service_instance) { Models::UserProvidedServiceInstance.make }

        it "deletes the service instance with the given guid" do
          expect {
            delete "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(Models::ServiceInstance, :count).by(-1)
          last_response.status.should == 204
          Models::ServiceInstance.find(:guid => service_instance.guid).should be_nil
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

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
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

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /login to your account and upgrade/
        end

        it "should enforce quota check on service plan type during creation" do
          org = Models::Organization.make(:quota_definition => free_quota_with_one_service)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => paid_plan.guid)

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /paid service plans are not allowed/
        end
      end

      context 'invalid space guid' do
        it "returns a user friendly error" do
          org = Models::Organization.make()
          space = Models::Space.make(:organization => org)
          service = Models::Service.make
          plan = Models::ServicePlan.make(free: true)

          body = {
            "space_guid" => "invalid_space_guid",
            "name" => 'name',
            "service_plan_guid" => plan.guid
          }

          post "/v2/service_instances", Yajl::Encoder.encode(body), json_headers(headers_for(make_developer_for_space(space)))
          decoded_response["description"].should =~ /invalid.*space.*/
          last_response.status.should == 400
        end
      end
    end
  end
end
