require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancesController, :services do
    it_behaves_like "an authenticated endpoint", path: "/v2/service_instances"
    include_examples "enumerating objects", path: "/v2/service_instances", model: ManagedServiceInstance
    include_examples "reading a valid object", path: "/v2/service_instances", model: ManagedServiceInstance, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/service_instances"
    include_examples "creating and updating",
      path: "/v2/service_instances",
      model: ManagedServiceInstance,
      required_attributes: %w(name space_guid service_plan_guid),
      unique_attributes: %w(space_guid name),
      extra_attributes: { credentials: -> { Sham.service_credentials } }
    include_examples "deleting a valid object", path: "/v2/service_instances", model: ManagedServiceInstance,
                     one_to_many_collection_ids: {
                       :service_bindings => lambda { |service_instance|
                         make_service_binding_for_service_instance(service_instance)
                       }
                     }
    include_examples "collection operations", path: "/v2/service_instances", model: ManagedServiceInstance,
                     one_to_many_collection_ids: {
                       service_bindings: lambda { |service_instance| make_service_binding_for_service_instance(service_instance) }
                     },
                     many_to_one_collection_ids: {},
                     many_to_many_collection_ids: {}

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = ManagedServiceInstance.make(:space => @space_a)
        @obj_b = ManagedServiceInstance.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid,
          :service_plan_guid => ServicePlan.make.guid
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

          it 'prevents a developer from creating a service instance in an unauthorized space' do
            plan = ServicePlan.make

            req = Yajl::Encoder.encode(
              :name => 'foo',
              :space_guid => @space_b.guid,
              :service_plan_guid => plan.guid
            )

            post "/v2/service_instances", req, json_headers(headers_for(member_a))

            last_response.status.should == 403
            Yajl::Parser.parse(last_response.body)['description'].should eq("You are not authorized to perform the requested action")
          end
        end

        describe "private plans" do
          let!(:unprivileged_organization) { Organization.make }
          let!(:private_plan) { ServicePlan.make(public: false) }
          let!(:unprivileged_space) { Space.make(organization: unprivileged_organization) }
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
              Yajl::Parser.parse(last_response.body)['description'].should eq("You are not authorized to perform the requested action")
            end
          end

          describe "a user who belongs to a privileged organization" do
            let!(:privileged_organization) do
              Organization.make.tap do |org|
                ServicePlanVisibility.create(
                  organization: org,
                  service_plan: private_plan
                )
              end
            end
            let!(:privileged_space) { Space.make(organization: privileged_organization) }

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
              Yajl::Parser.parse(last_response.body)['description'].should match('A service instance for the selected plan cannot be created in this organization.')
            end
          end
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
                           :name => 'managed service instance',
                           :path => "/v2/service_instances",
                           :enumerate => 1
        end
      end
    end

    describe 'POST', '/v2/service_instances' do
      context 'with a v2 service' do
        let(:space) { Space.make }
        let(:plan) { ServicePlan.make }
        let(:developer) { make_developer_for_space(space) }
        let(:client) { double('client') }

        before do
          client.stub(:provision) do |instance|
            instance.credentials = '{}'
            instance.dashboard_url = 'the dashboard_url'
          end
          client.stub(:deprovision)
          Service.any_instance.stub(:client).and_return(client)
        end

        it 'provisions a service instance' do
          instance = create_service_instance

          expect(last_response.status).to eq(201)

          expect(instance.credentials).to eq('{}')
          expect(instance.dashboard_url).to eq('the dashboard_url')
        end

        it 'creates a CREATED service usage event' do
          instance = nil
          expect {
            instance = create_service_instance
          }.to change{ServiceUsageEvent.count}.by(1)

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
          expect(event).to match_service_instance(instance)
        end

        context 'when name is blank' do
          let(:body) do
            Yajl::Encoder.encode(
              :name => '',
              :space_guid => space.guid,
              :service_plan_guid => plan.guid
            )
          end
          let(:headers) { json_headers(headers_for(developer)) }

          it 'returns a name validation error' do
            post '/v2/service_instances', body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match(/name is invalid/)
          end

          it 'does not provision or deprovision an instance' do
            post '/v2/service_instances', body, headers

            expect(client).to_not have_received(:provision)
            expect(client).to_not have_received(:deprovision)
          end

          it 'does not create a service instance' do
            expect {
              post '/v2/service_instances', body, headers
            }.to_not change(ServiceInstance, :count)
          end
        end

        it 'deprovisions the service instance when an exception is raised' do
          req = Yajl::Encoder.encode(
            :name => 'foo',
            :space_guid => space.guid,
            :service_plan_guid => plan.guid
          )

          ManagedServiceInstance.any_instance.stub(:save).and_raise

          post "/v2/service_instances", req, json_headers(headers_for(developer))

          expect(last_response.status).to eq(500)
          expect(client).to have_received(:deprovision).with(an_instance_of(ManagedServiceInstance))
        end

        context 'when the model save and the subsequent deprovision both raise errors' do
          let(:save_error_text) { "InvalidRequest" }
          let(:deprovision_error_text) { "NotAuthorized" }

          before do
            allow(client).to receive(:deprovision).and_raise(Errors::ApiError.new_from_details(deprovision_error_text))
            allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise(Errors::ApiError.new_from_details(save_error_text))
          end

          it 'raises the save error' do
            req = Yajl::Encoder.encode(
              :name => 'foo',
              :space_guid => space.guid,
              :service_plan_guid => plan.guid
            )

            post "/v2/service_instances", req, json_headers(headers_for(developer))

            expect(last_response.body).to_not match(deprovision_error_text)
            expect(last_response.body).to match(save_error_text)
          end
        end

        context 'creating a service instance with a name over 50 characters' do
        let(:very_long_name) { 's' * 51 }

        it "returns an error if the service instance name is over 50 characters" do
          req = Yajl::Encoder.encode(
            name: very_long_name,
            space_guid: space.guid,
            service_plan_guid: plan.guid
          )
          headers = json_headers(headers_for(developer))

          post "/v2/service_instances", req, headers

          last_response.status.should == 400
          decoded_response["description"].should =~ /service instance name.*limited to 50 characters/
        end
      end
      end

      context 'with a v1 service' do
        let(:space) { Space.make }
        let(:developer) { make_developer_for_space(space) }
        let(:plan) { ServicePlan.make(:service => service) }
        let(:service) { Service.make(:description => "blah blah foobar") }

        before do
          service.stub(:v2?) { false }
        end

        context 'when provisioning without a service-auth-token' do
          it 'should throw a 500 and give you an error message' do
            req = Yajl::Encoder.encode(
              :name => 'foo',
              :space_guid => space.guid,
              :service_plan_guid => plan.guid
            )
            headers = json_headers(headers_for(developer))

            expect(plan.service.service_auth_token).to eq(nil)

            post "/v2/service_instances", req, headers

            expect(last_response.status).to eq(500)
          end
        end

      end
    end

    describe 'GET', '/v2/service_instances' do
      let(:service_instance) { ManagedServiceInstance.make(gateway_name: Sham.name) }

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
          first_found_instance.should be_present
          first_found_instance.fetch('metadata').should be_present
          first_found_instance.fetch('metadata').fetch('guid').should == service_instance.guid
        end

        it 'allows filtering by name' do
          get "v2/service_instances?q=name:#{service_instance.name}", {}, admin_headers
          last_response.status.should == 200
          first_found_instance.fetch('entity').fetch('name').should == service_instance.name
        end

        it 'allows filtering by organization_guid' do
          ManagedServiceInstance.make(name: 'other')
          org_guid = service_instance.space.organization.guid

          get "v2/service_instances?q=organization_guid:#{org_guid}", {}, admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response['resources'].length).to eq(1)
          expect(first_found_instance.fetch('entity').fetch('name')).to eq(service_instance.name)
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
        let(:service_instance) { ManagedServiceInstance.make }

        it "returns the service instance with the given guid" do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          last_response.status.should == 200
          decoded_response.fetch('metadata').fetch('guid').should == service_instance.guid
        end
      end

      context 'with a user provided service instance' do
        let(:service_instance) { UserProvidedServiceInstance.make }

        it "returns the service instance with the given guid" do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          last_response.status.should == 200
          decoded_response.fetch('metadata').fetch('guid').should == service_instance.guid
        end
      end
    end

    describe 'PUT', '/v2/service_plans/:service_plan_guid/services_instances' do
      let(:first_service_plan)  { ServicePlan.make }
      let(:second_service_plan) { ServicePlan.make }
      let(:third_service_plan)  { ServicePlan.make }
      let(:space)               { Space.make }
      let(:developer)           { make_developer_for_space(space) }
      let(:new_plan_guid)       { third_service_plan.guid }
      let(:body) do
        Yajl::Encoder.encode(
          :service_plan_guid => new_plan_guid
        )
      end

      before do
        ManagedServiceInstance.make(service_plan: first_service_plan)
        ManagedServiceInstance.make(service_plan: second_service_plan)
        ManagedServiceInstance.make(service_plan: third_service_plan)
      end

      it 'updates all services instances for a given plan with the new plan id' do
        put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body, admin_headers

        expect(last_response.status).to eql(200)
        expect(first_service_plan.service_instances.count).to eql(0)
        expect(second_service_plan.service_instances.count).to eql(1)
        expect(third_service_plan.service_instances.count).to eql(2)
      end

      it 'returns the number of instances moved' do
        ManagedServiceInstance.make(service_plan: first_service_plan)

        put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body, admin_headers

        expect(decoded_response['changed_count']).to eql(2)
      end

      context 'when given an invalid new plan guid' do
        let(:new_plan_guid) { "a-plan-that-does-not-exist" }

        it 'does not update any service instances' do
          put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body, admin_headers

          expect(last_response.status).to eql(400)
          expect(first_service_plan.service_instances.count).to eql(1)
          expect(second_service_plan.service_instances.count).to eql(1)
          expect(third_service_plan.service_instances.count).to eql(1)
        end
      end

      context 'when given an invalid existing plan guid' do
        it 'does not update any service instances' do
          put "/v2/service_plans/some-non-existant-plan/service_instances", body, admin_headers

          expect(last_response.status).to eql(400)
          expect(first_service_plan.service_instances.count).to eql(1)
          expect(second_service_plan.service_instances.count).to eql(1)
          expect(third_service_plan.service_instances.count).to eql(1)
        end
      end

      it 'requires admin permissions' do
        put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body
        expect(last_response.status).to eql(401)

        put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body, json_headers(headers_for(developer))
        expect(last_response.status).to eql(403)

        put "/v2/service_plans/#{first_service_plan.guid}/service_instances", body, admin_headers
        expect(last_response.status).to eql(200)
      end
    end

    describe 'DELETE', '/v2/service_instances/:service_instance_guid' do
      context 'with a managed service instance' do
        let(:service) { Service.make(:v2) }
        let(:service_plan) { ServicePlan.make(service: service) }
        let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
        let(:body) { '{}' }
        let(:status) { 200 }

        before do
          guid = service_instance.guid
          plan_id = service_plan.unique_id
          service_id = service.unique_id
          path = "/v2/service_instances/#{guid}?plan_id=#{plan_id}&service_id=#{service_id}"
          uri = URI(service.service_broker.broker_url + path)
          uri.user = service.service_broker.auth_username
          uri.password = service.service_broker.auth_password
          stub_request(:delete, uri.to_s).to_return(body: body, status: status)
        end

        it "deletes the service instance with the given guid" do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(ServiceInstance, :count).by(-1)
          last_response.status.should == 204
          ServiceInstance.find(:guid => service_instance.guid).should be_nil
        end

        it 'creates a DELETED service usage event' do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change{ServiceUsageEvent.count}.by(1)
          event = ServiceUsageEvent.last
          # expect 2 events: CREATED and DELETED
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::DELETED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end

        context 'when the service broker returns a 409' do
          let(:body) {'{"description": "service broker error"}' }
          let(:status) { 409 }

          it 'forwards the error message from the service broker' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(last_response.status).to eq 409
            expect(JSON.parse(last_response.body)['description']).to include 'service broker error'
          end
        end
      end

      context 'with a v1 service instance' do
        let(:service) { Service.make(:v1) }
        let(:service_plan) { ServicePlan.make(service: service)}
        let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        context 'when the service gateway returns a 409' do
          before do
            # Stub 409
            VCAP::Services::ServiceBrokers::V1::HttpClient.unstub(:new)

            guid = service_instance.broker_provided_id
            path = "/gateway/v1/configurations/#{guid}"
            uri = URI(service.url + path)

            stub_request(:delete, uri.to_s).to_return(body: '{"description": "service gateway error"}', status: 409)
          end

          it 'forwards the error message from the service gateway' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(last_response.status).to eq 409
            expect(JSON.parse(last_response.body)['description']).to include 'service gateway error'
          end
        end

      end

      context 'with a user provided service instance' do
        let!(:service_instance) { UserProvidedServiceInstance.make }

        it "deletes the service instance with the given guid" do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(ServiceInstance, :count).by(-1)
          last_response.status.should == 204
          ServiceInstance.find(:guid => service_instance.guid).should be_nil
        end
      end
    end

    describe 'GET', '/v2/service_instances/:service_instance_guid/permissions' do
      let(:space)     { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when the user is a member of the space this instance exists in' do
        let(:instance)  { ServiceInstance.make(space: space) }

        context 'when the user has only the cloud_controller.read scope' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)
            expect(JSON.parse(last_response.body)['manage']).to be_true
          end
        end

        context 'when the user has only the cloud_controller_service_permissions.read scope' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller_service_permissions.read']}))
            expect(last_response.status).to eql(200)
            expect(JSON.parse(last_response.body)['manage']).to be_true
          end
        end

        context 'when the user does not have either necessary scope' do
          it 'returns InvalidAuthToken' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.write']}))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:instance)  { ServiceInstance.make }

        it 'returns a JSON payload indicating the user does not have permission to manage this instance' do
          get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(JSON.parse(last_response.body)['manage']).to be_false
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:instance)  { ServiceInstance.make }
        let(:developer) { nil }

        it 'returns an error saying that the user is not authenticated' do
          get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the service instance does not exist' do
        it 'returns an error saying the instance was not found' do
          get '/v2/service_instances/nonexistent_instance/permissions', {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql 404
        end
      end
    end

    describe "Quota enforcement" do
      let(:paid_quota) { QuotaDefinition.make(:total_services => 0) }
      let(:free_quota_with_no_services) do
        QuotaDefinition.make(:total_services => 0,
                                     :non_basic_services_allowed => false)
      end
      let(:free_quota_with_one_service) do
        QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end
      let(:paid_plan) { ServicePlan.make }
      let(:free_plan) { ServicePlan.make(:free => true) }

      context "paid quota" do
        it "should enforce quota check on number of service instances during creation" do
          org = Organization.make(:quota_definition => paid_quota)
          space = Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => paid_plan.guid)

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's services limit/
        end
      end

      context "free quota" do
        it "should enforce quota check on number of service instances during creation" do
          org = Organization.make(:quota_definition => free_quota_with_no_services)
          space = Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :service_plan_guid => free_plan.guid)

          post "/v2/service_instances", req, json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's services limit/
        end

        it "should enforce quota check on service plan type during creation" do
          org = Organization.make(:quota_definition => free_quota_with_one_service)
          space = Space.make(:organization => org)
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
          org = Organization.make()
          space = Space.make(:organization => org)
          plan = ServicePlan.make(free: true)

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

    def create_service_instance
      req = Yajl::Encoder.encode(
        :name => 'foo',
        :space_guid => space.guid,
        :service_plan_guid => plan.guid
      )
      headers = json_headers(headers_for(developer))

      post "/v2/service_instances", req, headers

      ServiceInstance.last
    end

  end
end
