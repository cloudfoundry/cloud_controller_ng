require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancesController, :services do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:service_plan_guid) }
      it { expect(described_class).to be_queryable_by(:service_binding_guid) }
      it { expect(described_class).to be_queryable_by(:gateway_name) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          space_guid: { type: 'string', required: true },
          service_plan_guid: { type: 'string', required: true },
          service_binding_guids: { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          space_guid: { type: 'string' },
          service_plan_guid: { type: 'string' },
          service_binding_guids: { type: '[string]' }
        })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = ManagedServiceInstance.make(space: @space_a)
        @obj_b = ManagedServiceInstance.make(space: @space_b)
      end

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples 'permission enumeration', user_role,
                           name: 'managed service instance',
                           path: '/v2/service_instances',
                           enumerate: 0
        end
      end

      describe 'Org Level Permissions' do
        user_sees_empty_enumerate('OrgManager',     :@org_a_manager,         :@org_b_manager)
        user_sees_empty_enumerate('OrgUser',        :@org_a_member,          :@org_b_member)
        user_sees_empty_enumerate('BillingManager', :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate('Auditor',        :@org_a_auditor,         :@org_b_auditor)
      end

      describe 'App Space Level Permissions' do
        user_sees_empty_enumerate('SpaceManager', :@space_a_manager, :@space_b_manager)

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
                           name: 'managed service instance',
                           path: '/v2/service_instances',
                           enumerate: 1

          it 'prevents a developer from creating a service instance in an unauthorized space' do
            plan = ServicePlan.make

            req = MultiJson.dump(
              name: 'foo',
              space_guid: @space_b.guid,
              service_plan_guid: plan.guid
            )

            post '/v2/service_instances', req, json_headers(headers_for(member_a))

            expect(last_response.status).to eq(403)
            expect(MultiJson.load(last_response.body)['description']).to eq('You are not authorized to perform the requested action')
          end
        end

        describe 'private plans' do
          let!(:unprivileged_organization) { Organization.make }
          let!(:private_plan) { ServicePlan.make(public: false) }
          let!(:unprivileged_space) { Space.make(organization: unprivileged_organization) }
          let!(:developer) { make_developer_for_space(unprivileged_space) }

          describe 'a user who does not belong to a privileged organization' do
            it 'does not allow a user to create a service instance' do
              payload = MultiJson.dump(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))

              expect(last_response.status).to eq(403)
              expect(MultiJson.load(last_response.body)['description']).to eq('You are not authorized to perform the requested action')
            end
          end

          describe 'a user who belongs to a privileged organization' do
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

            it 'allows user to create a service instance in a privileged organization' do
              payload = MultiJson.dump(
                'space_guid' => privileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))
              expect(last_response.status).to eq(201)
            end

            it 'does not allow a user to create a service instance in an unprivileged organization' do
              payload = MultiJson.dump(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload, json_headers(headers_for(developer))

              expect(last_response.status).to eq(403)
              expect(MultiJson.load(last_response.body)['description']).to match('A service instance for the selected plan cannot be created in this organization.')
            end
          end
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
                           name: 'managed service instance',
                           path: '/v2/service_instances',
                           enumerate: 1
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ service_bindings: [:get, :put, :delete] })
      end
    end

    describe 'POST', '/v2/service_instances' do
      context 'with a v2 service' do
        let(:space) { Space.make }
        let(:plan) { ServicePlan.make }
        let(:developer) { make_developer_for_space(space) }
        let(:client) { double('client') }

        before do
          allow(client).to receive(:provision) do |instance|
            instance.credentials = '{}'
            instance.dashboard_url = 'the dashboard_url'
            instance.state = 'creating'
            instance.state_description = ''
          end
          allow(client).to receive(:deprovision)
          allow_any_instance_of(Service).to receive(:client).and_return(client)
        end

        it 'provisions a service instance' do
          instance = create_managed_service_instance

          expect(last_response.status).to eq(201)

          expect(instance.credentials).to eq('{}')
          expect(instance.dashboard_url).to eq('the dashboard_url')
          expect(decoded_response['entity']['state']).to eq 'creating'
          expect(decoded_response['entity']['state_description']).to eq ''
        end

        it 'creates a service audit event for creating the service instance' do
          instance = create_managed_service_instance(email: 'developer@example.com')

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.create')
          expect(event.type).to eq('audit.service_instance.create')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('developer@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(instance.name)
          expect(event.space_guid).to eq(instance.space.guid)
          expect(event.space_id).to eq(instance.space.id)
          expect(event.organization_guid).to eq(instance.space.organization.guid)
          expect(event.metadata).to include({
            'request' => {
              'name' => instance.name,
              'service_plan_guid' => instance.service_plan_guid,
              'space_guid' => instance.space_guid,
            }
          })
        end

        it 'creates a CREATED service usage event' do
          instance = nil
          expect {
            instance = create_managed_service_instance
          }.to change { ServiceUsageEvent.count }.by(1)

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
          expect(event).to match_service_instance(instance)
        end

        context 'when name is blank' do
          let(:body) do
            MultiJson.dump(
              name: '',
              space_guid: space.guid,
              service_plan_guid: plan.guid
            )
          end
          let(:headers) { json_headers(headers_for(developer)) }

          it 'returns a name validation error' do
            post '/v2/service_instances', body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq 60001
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
          req = MultiJson.dump(
            name: 'foo',
            space_guid: space.guid,
            service_plan_guid: plan.guid
          )

          allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise

          post '/v2/service_instances', req, json_headers(headers_for(developer))

          expect(last_response.status).to eq(500)
          expect(client).to have_received(:deprovision).with(an_instance_of(ManagedServiceInstance))
        end

        context 'when the model save and the subsequent deprovision both raise errors' do
          let(:save_error_text) { 'InvalidRequest' }
          let(:deprovision_error_text) { 'NotAuthorized' }

          before do
            allow(client).to receive(:deprovision).and_raise(Errors::ApiError.new_from_details(deprovision_error_text))
            allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise(Errors::ApiError.new_from_details(save_error_text))
          end

          it 'raises the save error' do
            req = MultiJson.dump(
              name: 'foo',
              space_guid: space.guid,
              service_plan_guid: plan.guid
            )

            post '/v2/service_instances', req, json_headers(headers_for(developer))

            expect(last_response.body).to_not match(deprovision_error_text)
            expect(last_response.body).to match(save_error_text)
          end
        end

        context 'creating a service instance with a name over 50 characters' do
          let(:very_long_name) { 's' * 51 }

          it 'returns an error if the service instance name is over 50 characters' do
            req = MultiJson.dump(
              name: very_long_name,
              space_guid: space.guid,
              service_plan_guid: plan.guid
            )
            headers = json_headers(headers_for(developer))

            post '/v2/service_instances', req, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq 60009
          end
        end

        context 'with naming collisions' do
          it 'does not allow duplicate managed service instances' do
            create_managed_service_instance
            expect(last_response.status).to eq(201)

            create_managed_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end

          it 'does not allow duplicate user provided service instances' do
            create_user_provided_service_instance
            expect(last_response.status).to eq(201)

            create_user_provided_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end

          it 'does not allow a user provided service instance with same name as managed service instance' do
            create_managed_service_instance
            expect(last_response.status).to eq(201)

            create_user_provided_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end

          it 'does not allow a managed service instance with same name as user provided service instance' do
            create_user_provided_service_instance
            expect(last_response.status).to eq(201)

            create_managed_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end
        end

        context 'when the service_plan does not exist' do
          before do
            req = MultiJson.dump(
              name: 'foo',
              space_guid: space.guid,
              service_plan_guid: 'bad-guid'
            )
            headers = json_headers(headers_for(developer))

            post '/v2/service_instances', req, headers
          end

          it 'returns a 404' do
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60003)
            expect(decoded_response['description']).to include('not a valid service plan')
          end
        end
      end

      context 'with a v1 service' do
        let(:space) { Space.make }
        let(:developer) { make_developer_for_space(space) }
        let(:plan) { ServicePlan.make(service: service) }
        let(:service) { Service.make(description: 'blah blah foobar') }

        before do
          allow(service).to receive(:v2?) { false }
        end

        context 'when provisioning without a service-auth-token' do
          it 'should throw a 500 and give you an error message' do
            req = MultiJson.dump(
              name: 'foo',
              space_guid: space.guid,
              service_plan_guid: plan.guid
            )
            headers = json_headers(headers_for(developer))

            expect(plan.service.service_auth_token).to eq(nil)

            post '/v2/service_instances', req, headers

            expect(last_response.status).to eq(500)
          end
        end
      end
    end

    describe 'GET', '/v2/service_instances' do
      let(:service_instance) { ManagedServiceInstance.make(gateway_name: Sham.name) }

      it 'shows the dashboard_url if there is' do
        service_instance.update(dashboard_url: 'http://dashboard.io')
        get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
        expect(decoded_response.fetch('entity').fetch('dashboard_url')).to eq('http://dashboard.io')
      end

      context 'filtering' do
        let(:first_found_instance) { decoded_response.fetch('resources').first }

        it 'allows filtering by organization_guid' do
          ManagedServiceInstance.make(name: 'other')
          org_guid = service_instance.space.organization.guid

          get "v2/service_instances?q=organization_guid:#{org_guid}", {}, admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response['resources'].length).to eq(1)
          expect(first_found_instance.fetch('entity').fetch('name')).to eq(service_instance.name)
        end
      end
    end

    describe 'GET', '/v2/service_instances/:service_instance_guid' do
      context 'with a managed service instance' do
        let(:service_instance) { ManagedServiceInstance.make }

        it 'returns the service instance with the given guid' do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('metadata').fetch('guid')).to eq(service_instance.guid)
        end
      end

      context 'with a user provided service instance' do
        let(:service_instance) { UserProvidedServiceInstance.make }

        it 'returns the service instance with the given guid' do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('metadata').fetch('guid')).to eq(service_instance.guid)
        end

        it 'returns the bindings URL with user_provided_service_instance' do
          get "v2/service_instances/#{service_instance.guid}", {}, admin_headers
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('entity').fetch('service_bindings_url')).to include('user_provided_service_instances')
        end
      end
    end

    describe 'PUT', '/v2/service_instances/:service_instance_guid' do
      let(:service) { Service.make(plan_updateable: true) }
      let(:old_service_plan)  { ServicePlan.make(:v2, service: service) }
      let(:new_service_plan)  { ServicePlan.make(:v2, service: service) }
      let(:service_instance)  { ManagedServiceInstance.make(service_plan: old_service_plan) }

      let(:body) do
        MultiJson.dump(
          service_plan_guid: new_service_plan.guid
        )
      end

      let(:client) { double('client') }

      before do
        allow(client).to receive(:update_service_plan)
        allow_any_instance_of(Service).to receive(:client).and_return(client)
      end

      context 'when the broker declared support for plan upgrades' do
        it 'calls the service broker to update the plan' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(client).to have_received(:update_service_plan).with(service_instance, new_service_plan)
        end

        it 'updates the service plan in the database' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(service_instance.reload.service_plan).to eq(new_service_plan)
        end

        it 'creates a service audit event for updating the service instance' do
          put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
          expect(event.type).to eq('audit.service_instance.update')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(admin_user.guid)
          expect(event.actor_name).to eq('admin@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.space_id).to eq(service_instance.space.id)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata).to include({
            'request' => {
              'service_plan_guid' => new_service_plan.guid,
            }
          })
        end
      end

      context 'When the broker did not declare support for plan upgrades' do
        let(:old_service_plan) { ServicePlan.make(:v2) }

        it 'does not update the service plan in the database' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(service_instance.reload.service_plan).to eq(old_service_plan)
        end

        it 'does not make an api call when the plan does not support upgrades' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(client).not_to have_received(:update_service_plan)
        end

        it 'returns a useful error to the user' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(last_response.body).to match /The service does not support changing plans/
        end
      end

      context 'When the user has read but not write permissions' do
        let(:auditor) { User.make }

        before do
          service_instance.space.organization.add_auditor(auditor)
        end

        it 'does not call out to the service broker' do
          put "/v2/service_instances/#{service_instance.guid}", body, headers_for(auditor)
          expect(client).not_to have_received(:update_service_plan)
        end
      end

      context 'when the requested plan does not exist' do
        let(:body) do
          MultiJson.dump(
            service_plan_guid: 'some-non-existing-plan'
          )
        end

        it 'returns an InvalidRelationError' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(last_response.status).to eq 400
          expect(last_response.body).to match 'InvalidRelation'
          expect(service_instance.reload.service_plan).to eq(old_service_plan)
        end
      end

      context 'when the broker client raises a ServiceBrokerBadResponse' do
        let(:uri) { 'http://uri.example.com' }
        let(:method) { 'GET' }
        let(:response_body) { '{"description": "error message"}' }
        let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_body) }

        before do
          allow(client).to receive(:update_service_plan).and_raise(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(uri, method, response))
        end

        it 'returns a CF-ServiceBrokerBadResponse' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(last_response.status).to eq 502
          expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerBadResponse'
        end
      end

      context 'when the broker client raises a ServiceBrokerRequestRejected' do
        let(:uri) { 'http://uri.example.com' }
        let(:method) { 'GET' }
        let(:response_body) { '{"description": "error message"}' }
        let(:response) { double(code: 422, reason: 'Broker rejected the upate', body: response_body) }

        before do
          allow(client).to receive(:update_service_plan).and_raise(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerRequestRejected.new(uri, method, response))
        end

        it 'returns a CF-ServiceBrokerBadResponse' do
          put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
          expect(last_response.status).to eq 502
          expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerRequestRejected'
        end
      end

      describe 'the space_guid parameter' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:user) { make_developer_for_space(space) }
        let(:instance) { ManagedServiceInstance.make(space: space) }

        it 'prevents a developer from moving the service instance to a space for which he is also a space developer' do
          space2 = Space.make(organization: org)
          space2.add_developer(user)

          move_req = MultiJson.dump(
            space_guid: space2.guid,
          )

          put "/v2/service_instances/#{instance.guid}", move_req, json_headers(headers_for(user))

          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match /Cannot update space for service instance/
        end

        it 'succeeds when the space_guid does not change' do
          req = MultiJson.dump(space_guid: instance.space.guid)
          put "/v2/service_instances/#{instance.guid}", req, json_headers(headers_for(user))
          expect(last_response.status).to eq 201
        end

        it 'succeeds when the space_guid is not provided' do
          put "/v2/service_instances/#{instance.guid}", {}.to_json, json_headers(headers_for(user))
          expect(last_response.status).to eq 201
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
        MultiJson.dump(
          service_plan_guid: new_plan_guid
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
        let(:new_plan_guid) { 'a-plan-that-does-not-exist' }

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
          put '/v2/service_plans/some-non-existant-plan/service_instances', body, admin_headers

          expect(last_response.status).to eql(400)
          expect(first_service_plan.service_instances.count).to eql(1)
          expect(second_service_plan.service_instances.count).to eql(1)
          expect(third_service_plan.service_instances.count).to eql(1)
        end
      end

      it 'requires admin permissions' do
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

        it 'deletes the service instance with the given guid' do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(ServiceInstance, :count).by(-1)
          expect(last_response.status).to eq(204)
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end

        context 'it is a managed service instance' do
          it 'creates a service audit event for deleting the service instance' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, headers_for(admin_user, email: 'admin@example.com')

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
            expect(event.type).to eq('audit.service_instance.delete')
            expect(event.actor_type).to eq('user')
            expect(event.actor).to eq(admin_user.guid)
            expect(event.actor_name).to eq('admin@example.com')
            expect(event.timestamp).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.actee_type).to eq('service_instance')
            expect(event.actee_name).to eq(service_instance.name)
            expect(event.space_guid).to eq(service_instance.space.guid)
            expect(event.space_id).to eq(service_instance.space.id)
            expect(event.organization_guid).to eq(service_instance.space.organization.guid)
            expect(event.metadata).to eq({ 'request' => {} })
          end
        end

        context 'it is a user provided service instance' do
          let!(:service_instance) { UserProvidedServiceInstance.make }

          it 'creates a user_provided_service_instance audit event for deleting the service instance' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, headers_for(admin_user, email: 'admin@example.com')

            event = VCAP::CloudController::Event.first(type: 'audit.user_provided_service_instance.delete')
            expect(event.type).to eq('audit.user_provided_service_instance.delete')
            expect(event.actor_type).to eq('user')
            expect(event.actor).to eq(admin_user.guid)
            expect(event.actor_name).to eq('admin@example.com')
            expect(event.timestamp).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.actee_type).to eq('user_provided_service_instance')
            expect(event.actee_name).to eq(service_instance.name)
            expect(event.space_guid).to eq(service_instance.space.guid)
            expect(event.space_id).to eq(service_instance.space.id)
            expect(event.organization_guid).to eq(service_instance.space.organization.guid)
            expect(event.metadata).to eq({ 'request' => {} })
          end
        end

        context 'with ?async=true' do
          it 'returns a job id' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, admin_headers
            expect(last_response.status).to eq 202
            expect(decoded_response['entity']['guid']).to be
            expect(decoded_response['entity']['status']).to eq 'queued'

            successes, failures = Delayed::Worker.new.work_off
            expect(successes).to eq 1
            expect(failures).to eq 0
            expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
          end
        end

        context 'when the service broker returns a 409' do
          let(:body) { '{"description": "service broker error"}' }
          let(:status) { 409 }

          it 'forwards the error message from the service broker' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(last_response.status).to eq 409
            expect(JSON.parse(last_response.body)['description']).to include 'service broker error'
          end
        end

        context 'and the instance cannot be found' do
          it 'returns a 404' do
            delete '/v2/service_instances/non-existing-instance', {}, admin_headers
            expect(last_response.status).to eq 404
          end
        end
      end

      context 'with a v1 service instance' do
        let(:service) { Service.make(:v1) }
        let(:service_plan) { ServicePlan.make(service: service) }
        let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        context 'when the service gateway returns a 409' do
          before do
            # Stub 409
            allow(VCAP::Services::ServiceBrokers::V1::HttpClient).to receive(:new).and_call_original

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

        it 'deletes the service instance with the given guid' do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(ServiceInstance, :count).by(-1)
          expect(last_response.status).to eq(204)
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end
      end
    end

    describe 'GET', '/v2/service_instances/:service_instance_guid/permissions' do
      let(:space)     { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when the user is a member of the space this instance exists in' do
        let(:instance)  { ManagedServiceInstance.make(space: space) }

        context 'when the user has only the cloud_controller.read scope' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)
            expect(JSON.parse(last_response.body)['manage']).to be true
          end
        end

        context 'when the user has only the cloud_controller_service_permissions.read scope' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, { scopes: ['cloud_controller_service_permissions.read'] }))
            expect(last_response.status).to eql(200)
            expect(JSON.parse(last_response.body)['manage']).to be true
          end
        end

        context 'when the user does not have either necessary scope' do
          it 'returns InvalidAuthToken' do
            get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer, { scopes: ['cloud_controller.write'] }))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:instance)  { ManagedServiceInstance.make }

        it 'returns a JSON payload indicating the user does not have permission to manage this instance' do
          get "/v2/service_instances/#{instance.guid}/permissions", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(JSON.parse(last_response.body)['manage']).to be false
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:instance)  { ManagedServiceInstance.make }
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

    describe 'Validation messages' do
      let(:paid_quota) { QuotaDefinition.make(total_services: 1) }
      let(:free_quota_with_no_services) do
        QuotaDefinition.make(
          total_services: 0,
          non_basic_services_allowed: false
        )
      end
      let(:free_quota_with_one_service) do
        QuotaDefinition.make(
          total_services: 1,
          non_basic_services_allowed: false
        )
      end
      let(:paid_plan) { ServicePlan.make }
      let(:free_plan) { ServicePlan.make(free: true) }
      let(:org) { Organization.make(quota_definition: paid_quota) }
      let(:space) { Space.make(organization: org) }

      it 'returns duplicate name message correctly' do
        existing_service_instance = ManagedServiceInstance.make(space: space)
        service_instance_params = {
          name: existing_service_instance.name,
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60002)
      end

      it 'returns space quota exceeded message correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(total_services: 0, organization: space.organization)
        space.save
        service_instance_params = {
          name: 'name',
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60012)
      end

      it 'returns service plan not allowed by space quota message correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(non_basic_services_allowed: false, organization: space.organization)
        space.save
        service_instance_params = {
          name: 'name',
          space_guid: space.guid,
          service_plan_guid: paid_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60013)
      end

      it 'returns quota exceeded message correctly' do
        org.quota_definition.total_services = 0
        org.quota_definition.save
        service_instance_params = {
          name: 'name',
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60005)
      end

      it 'returns service plan not allowed by quota message correctly' do
        org.quota_definition.non_basic_services_allowed = false
        org.quota_definition.save
        service_instance_params = {
          name: 'name',
          space_guid: space.guid,
          service_plan_guid: paid_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60007)
      end

      it 'returns service plan name too long message correctly' do
        service_instance_params = {
          name: 'n' * 51,
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60009)
      end

      context 'invalid space guid' do
        it 'returns a user friendly error' do
          org = Organization.make
          space = Space.make(organization: org)
          plan = ServicePlan.make(free: true)

          body = {
            'space_guid' => 'invalid_space_guid',
            'name' => 'name',
            'service_plan_guid' => plan.guid
          }

          post '/v2/service_instances', MultiJson.dump(body), json_headers(headers_for(make_developer_for_space(space)))
          expect(decoded_response['description']).to match(/invalid.*space.*/)
          expect(last_response.status).to eq(400)
        end
      end
    end

    def create_managed_service_instance(user_opts={})
      req = MultiJson.dump(
        name: 'foo',
        space_guid: space.guid,
        service_plan_guid: plan.guid
      )
      headers = json_headers(headers_for(developer, user_opts))

      post '/v2/service_instances', req, headers

      ServiceInstance.last
    end

    def create_user_provided_service_instance
      req = MultiJson.dump(
        name: 'foo',
        space_guid: space.guid
      )
      headers = json_headers(headers_for(developer))

      post '/v2/user_provided_service_instances', req, headers

      ServiceInstance.last
    end
  end
end
