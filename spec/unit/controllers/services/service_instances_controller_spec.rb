require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancesController, :services do
    let(:service_broker_url_regex) { %r{http://auth_username:auth_password@example.com/v2/service_instances/(.*)} }

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
          service_binding_guids: { type: '[string]' },
          service_key_guids: { type: '[string]' },
          parameters: { type: 'hash', default: nil },
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          space_guid: { type: 'string' },
          service_plan_guid: { type: 'string' },
          service_binding_guids: { type: '[string]' },
          service_key_guids: { type: '[string]' },
          parameters: { type: 'hash' },
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
            plan = ServicePlan.make(:v2)

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
          let!(:private_plan) { ServicePlan.make(:v2, public: false) }
          let!(:unprivileged_space) { Space.make(organization: unprivileged_organization) }
          let!(:developer) { make_developer_for_space(unprivileged_space) }

          before do
            stub_request(:put, service_broker_url_regex).
              with(headers: { 'Accept' => 'application/json' }).
              to_return(
                status: 201,
                body: { dashboard_url: 'url.com', state: 'succeeded', state_description: '100%' }.to_json,
                headers: { 'Content-Type' => 'application/json' })
          end

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

            let(:service_broker_url_regex) do
              broker = private_plan.service.service_broker
              uri = URI(broker.broker_url)
              broker_url = uri.host + uri.path
              %r{https://#{broker.auth_username}:#{broker.auth_password}@#{broker_url}/v2/service_instances/(.*)}
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
        expect(described_class).to have_nested_routes({ service_bindings: [:get, :put, :delete], service_keys: [:get, :put, :delete] })
      end
    end

    describe 'POST', '/v2/service_instances' do
      context 'with a v2 service' do
        let(:service_broker_url) { "http://auth_username:auth_password@example.com/v2/service_instances/#{ServiceInstance.last.guid}" }
        let(:service_broker_url_with_accepts_incomplete) { "#{service_broker_url}?accepts_incomplete=true" }
        let(:service_broker) { ServiceBroker.make(broker_url: 'http://example.com', auth_username: 'auth_username', auth_password: 'auth_password') }
        let(:service) { Service.make(service_broker: service_broker) }
        let(:space) { Space.make }
        let(:plan) { ServicePlan.make(:v2, service: service) }
        let(:developer) { make_developer_for_space(space) }
        let(:response_body) do
          {
            dashboard_url: 'the dashboard_url',
          }.to_json
        end
        let(:response_code) { 201 }

        def stub_delete_and_return(status, body)
          stub_request(:delete, service_broker_url_regex).
            with(headers: { 'Accept' => 'application/json' }).
            to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
        end

        before do
          stub_request(:put, service_broker_url_regex).
            with(headers: { 'Accept' => 'application/json' }).
            to_return(status: response_code, body: response_body, headers: { 'Content-Type' => 'application/json' })

          stub_delete_and_return(200, '{}')
        end

        it 'provisions a service instance' do
          instance = create_managed_service_instance(accepts_incomplete: 'false')

          expect(last_response.status).to eq(201)

          expect(instance.credentials).to eq({})
          expect(instance.dashboard_url).to eq('the dashboard_url')
          last_operation = decoded_response['entity']['last_operation']
          expect(last_operation['state']).to eq 'succeeded'
          expect(last_operation['description']).to eq ''
          expect(last_operation['type']).to eq 'create'
          expect(last_operation['updated_at']).not_to be_nil
        end

        it 'creates a CREATED service usage event' do
          instance = nil
          expect {
            instance = create_managed_service_instance(accepts_incomplete: 'false')
          }.to change { ServiceUsageEvent.count }.by(1)

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
          expect(event).to match_service_instance(instance)
        end

        context 'when the client provides arbitrary parameters' do
          before do
            create_managed_service_instance(
              email: 'developer@example.com',
              accepts_incomplete: false,
              parameters: parameters
            )
          end

          context 'and the parameter is a JSON object' do
            let(:parameters) do
              { foo: 'bar', bar: 'baz' }
            end

            it 'should pass along the parameters to the service broker' do
              expect(last_response).to have_status_code(201)
              expect(a_request(:put, service_broker_url_regex).
                  with(body: hash_including(parameters: parameters))).
                to have_been_made.times(1)
            end
          end

          context 'and the parameter is not a JSON object' do
            let(:parameters) { 'foo' }

            it 'should reject the request' do
              expect(last_response).to have_status_code(400)
              expect(a_request(:put, service_broker_url_regex).
                  with(body: hash_including(parameters: parameters))).
                to have_been_made.times(0)
            end
          end
        end

        context 'when the client does not support accepts_incomplete parameter' do
          let(:response_body) do
            {}.to_json
          end

          it 'creates a service audit event for creating the service instance' do
            instance = create_managed_service_instance(email: 'developer@example.com', accepts_incomplete: false)

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

          it 'tells the service broker to provision a new service instance synchronously' do
            create_managed_service_instance(accepts_incomplete: false)

            expect(a_request(:put, service_broker_url)).to have_been_made.times(1)
            expect(a_request(:delete, service_broker_url)).to have_been_made.times(0)
          end

          it 'fails with with InvalidRequest when accepts_incomplete is not true or false strings' do
            create_managed_service_instance(accepts_incomplete: 'lol')

            expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(0)
            expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(0)
            expect(last_response.status).to eq(400)
          end

          context 'but the broker rejects synchronous provisioning' do
            before do
              stub_request(:put, service_broker_url_regex).
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 422, body: { error: 'AsyncRequired' }.to_json, headers: { 'Content-Type' => 'application/json' })
            end

            it 'fails with an AsyncRequired error' do
              create_managed_service_instance
              expect(last_response).to have_status_code(400)
              expect(decoded_response['error_code']).to eq 'CF-AsyncRequired'
            end

            it 'does not create an audit event' do
              create_managed_service_instance
              event = VCAP::CloudController::Event.first(type: 'audit.service_instance.create')
              expect(event).to be_nil
            end
          end
        end

        context 'when the client explicitly allows accepts_incomplete' do
          let(:response_code) { 202 }
          let(:response_body) do
            {}.to_json
          end

          it 'tells the service broker to provision a new service instance with accepts_incomplete=true' do
            create_managed_service_instance

            expect(a_request(:put, service_broker_url_with_accepts_incomplete)).to have_been_made.times(1)
            expect(a_request(:delete, service_broker_url)).to have_been_made.times(0)
          end

          it 'does not create an audit event' do
            create_managed_service_instance

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.create')
            expect(event).to be_nil
          end

          it 'returns a 202 with the last operation state as in progress' do
            service_instance = create_managed_service_instance

            expect(last_response).to have_status_code(202)
            expect(service_instance.last_operation.state).to eq('in progress')
          end

          context 'and the broker provisions the instance synchronously' do
            let(:response_code) { 201 }

            it 'returns a 201 with the last operation state as succeeded' do
              service_instance = create_managed_service_instance

              expect(last_response).to have_status_code(201)
              expect(service_instance.last_operation.state).to eq('succeeded')
            end
          end

          context 'and the worker processes the request successfully' do
            before do
              stub_request(:get, service_broker_url_regex).
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 200, body: {
                  last_operation: {
                    state: 'succeeded',
                    description: 'new description'
                  }
                }.to_json)
            end

            it 'updates the description of the service instance last operation' do
              service_instance = create_managed_service_instance(email: 'developer@example.com')

              Delayed::Job.last.invoke_job

              expect(service_instance.last_operation.reload.state).to eq('succeeded')
              expect(service_instance.last_operation.reload.description).to eq('new description')
            end

            it 'creates an audit event' do
              instance = create_managed_service_instance(email: 'developer@example.com')

              Delayed::Job.last.invoke_job

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
          end
        end

        context 'when the client explicitly does not request accepts_incomplete provisioning' do
          it 'tells the service broker to provision a new service instance synchronous' do
            create_managed_service_instance(accepts_incomplete: 'false')

            expect(a_request(:put, service_broker_url)).to have_been_made.times(1)
            expect(a_request(:delete, service_broker_url)).to have_been_made.times(0)
          end

          it 'creates a service audit event for creating the service instance' do
            instance = create_managed_service_instance(email: 'developer@example.com', accepts_incomplete: 'false')

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
        end

        context 'the service broker says there is a conflict' do
          let(:response_body) do
            MultiJson.dump(
              description: 'some-error',
            )
          end
          let(:response_code) { 409 }

          it "should return an error with broker's error message" do
            create_managed_service_instance(email: 'developer@example.com')

            expect(last_response.body).to include('Service broker error: some-error')
          end
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

            expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(0)
            expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(0)
          end

          it 'does not create a service instance' do
            expect {
              post '/v2/service_instances', body, headers
            }.to_not change(ServiceInstance, :count)
          end
        end

        context 'when the model save and the subsequent deprovision both raise errors' do
          let(:save_error_text) { 'InvalidRequest' }
          let(:deprovision_error_text) { 'NotAuthorized' }

          before do
            stub_delete_and_return(403, '{}')
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
            create_managed_service_instance(accepts_incomplete: 'false')
            expect(last_response.status).to eq(201)

            create_managed_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end

          it 'does not allow duplicate user provided service instances' do
            create_managed_service_instance(accepts_incomplete: 'false')
            expect(last_response.status).to eq(201)

            create_user_provided_service_instance
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(60002)
          end

          it 'does not allow a user provided service instance with same name as managed service instance' do
            create_managed_service_instance(accepts_incomplete: 'false')
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
            expect(last_response).to have_status_code(400)
            expect(decoded_response['code']).to eq(60003)
            expect(decoded_response['description']).to include('not a valid service plan')
          end
        end

        describe 'orphan mitigation' do
          context 'when the broker returns an error' do
            let(:response_code) { 500 }

            it 'enqueues a job to deprovision the instance' do
              req = MultiJson.dump(
                name: 'foo',
                space_guid: space.guid,
                service_plan_guid: plan.guid
              )

              post '/v2/service_instances', req, json_headers(headers_for(developer))

              expect(last_response.status).to eq(502)
              expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(1)
              expect(a_request(:delete, service_broker_url_regex)).not_to have_been_made.times(1)

              orphan_mitigation_job = Delayed::Job.first
              expect(orphan_mitigation_job).not_to be_nil
              expect(orphan_mitigation_job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceDeprovision
            end
          end

          context 'when the instance fails to save to the DB' do
            it 'deprovisions the service instance' do
              req = MultiJson.dump(
                name: 'foo',
                space_guid: space.guid,
                service_plan_guid: plan.guid
              )

              allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise

              post '/v2/service_instances', req, json_headers(headers_for(developer))

              expect(last_response.status).to eq(500)
              expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(1)
              expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(1)

              orphan_mitigation_job = Delayed::Job.first
              expect(orphan_mitigation_job).to be_nil
            end
          end
        end
      end

      context 'with a v1 service' do
        let(:space) { Space.make }
        let(:developer) { make_developer_for_space(space) }
        let(:plan) { ServicePlan.make(:v1, service: service) }
        let(:service) { Service.make(:v1, description: 'blah blah foobar') }

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
      let(:service_broker_url) { "http://auth_username:auth_password@example.com/v2/service_instances/#{service_instance.guid}" }
      let(:service_broker) { ServiceBroker.make(broker_url: 'http://example.com', auth_username: 'auth_username', auth_password: 'auth_password') }
      let(:service) { Service.make(plan_updateable: true, service_broker: service_broker) }
      let(:old_service_plan)  { ServicePlan.make(:v2, service: service) }
      let(:new_service_plan)  { ServicePlan.make(:v2, service: service) }
      let(:service_instance)  { ManagedServiceInstance.make(service_plan: old_service_plan) }

      let(:body) do
        MultiJson.dump(
          service_plan_guid: new_service_plan.guid
        )
      end

      let(:status) { 200 }
      let(:response_body) { '{}' }

      context 'when the request is synchronous' do
        before do
          stub_request(:patch, "#{service_broker_url}").
            to_return(status: status, body: response_body)
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

        it 'returns a 201' do
          put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')
          expect(last_response).to have_status_code 201
        end

        context 'when the request has arbitrary parameters' do
          let(:body) do
            {
              service_plan_guid: new_service_plan.guid,
              parameters: parameters
            }.to_json
          end

          let(:parameters) do
            { myParam: 'some-value' }
          end

          it 'should pass along the parameters to the service broker' do
            put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')
            expect(last_response).to have_status_code(201)
            expect(a_request(:patch, service_broker_url_regex).with(body: hash_including(parameters: parameters))).to have_been_made.times(1)
          end

          context 'and the parameter is not a JSON object' do
            let(:parameters) { 'foo' }

            it 'should reject the request' do
              put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')
              expect(last_response).to have_status_code(400)
              expect(a_request(:put, service_broker_url_regex).
                       with(body: hash_including(parameters: parameters))).
                to have_been_made.times(0)
            end
          end
        end

        context 'when the request is a service instance rename' do
          let(:status) { 200 }
          let(:body) do
            MultiJson.dump(
              name: 'new-name'
            )
          end
          let(:last_operation) { ServiceInstanceOperation.make(state: 'succeeded') }
          let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }

          before do
            service_instance.service_instance_operation = last_operation
            service_instance.save
          end

          it 'updates service instance name in the database' do
            put "/v2/service_instances/#{service_instance.guid}", body, admin_headers

            expect(service_instance.reload.name).to eq('new-name')
          end

          it 'updates operation status to succeeded in the database' do
            put "/v2/service_instances/#{service_instance.guid}", body, admin_headers

            expect(service_instance.reload.last_operation.state).to eq('succeeded')
          end
        end

        context 'when the request is to update the instance to the plan it already has' do
          let(:body) do
            MultiJson.dump(
              service_plan_guid: old_service_plan.guid
            )
          end

          it 'does not make a request to the broker' do
            put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')

            expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
          end

          it 'marks last_operation state as `succeeded`' do
            put "/v2/service_instances/#{service_instance.guid}", body, headers_for(admin_user, email: 'admin@example.com')

            expect(service_instance.last_operation.reload.state).to eq 'succeeded'
            expect(service_instance.last_operation.reload.description).to be_nil
          end
        end

        describe 'error cases' do
          context 'when the service instance has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
            before do
              service_instance.service_instance_operation = last_operation
              service_instance.save
            end

            it 'should show an error message for update operation' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
              expect(last_response).to have_status_code 400
              expect(last_response.body).to match 'ServiceInstanceOperationInProgress'
            end
          end

          context 'when the broker did not declare support for plan upgrades' do
            let(:old_service_plan) { ServicePlan.make(:v2) }

            before { service.update(plan_updateable: false) }

            it 'does not update the service plan in the database' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end

            it 'does not make an api call when the plan does not support upgrades' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
            end

            it 'returns a useful error to the user' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers
              expect(last_response.body).to match /The service does not support changing plans/
            end
          end

          context 'when the user has read but not write permissions' do
            let(:auditor) { User.make }

            before do
              service_instance.space.organization.add_auditor(auditor)
            end

            it 'does not call out to the service broker' do
              put "/v2/service_instances/#{service_instance.guid}", body, headers_for(auditor)
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
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

          context 'when the broker client returns an error as its second return value' do
            let(:response_body) { '{"description": "error message"}' }

            before do
              stub_request(:patch, service_broker_url).
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 500, body: response_body, headers: { 'Content-Type' => 'application/json' })
            end

            it 'saves the attributes provided by the first return value' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers

              expect(service_instance.last_operation.state).to eq 'failed'
              expect(service_instance.last_operation.type).to eq 'update'
              expect(service_instance.last_operation.description).to eq 'Service broker error: error message'
            end

            it 're-raises the error' do
              put "/v2/service_instances/#{service_instance.guid}", body, admin_headers

              expect(last_response).to have_status_code 502
            end
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
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end

          it 'succeeds when the space_guid is not provided' do
            put "/v2/service_instances/#{instance.guid}", {}.to_json, json_headers(headers_for(user))
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end
        end
      end

      context 'when the request allows accepts_incomplete update' do
        before do
          stub_request(:patch, "#{service_broker_url}?accepts_incomplete=true").
            to_return(status: status, body: response_body)
        end

        it 'creates a service audit event for updating the service instance' do
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

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

        it 'updates the service plan in the database' do
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

          expect(service_instance.reload.service_plan).to eq(new_service_plan)
        end

        it 'returns 201' do
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
          expect(last_response).to have_status_code 201
        end

        context 'when the broker returns a 202' do
          let(:status) { 202 }

          it 'does not update the service plan in the database' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

            expect(service_instance.reload.service_plan).to eq(old_service_plan)
          end

          it 'does not create an audit event' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
            expect(event).to be_nil
          end

          it 'returns a 202' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')
            expect(last_response).to have_status_code 202
          end

          it 'enqueues a job to fetch the state' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user)
            expect(Delayed::Job.count).to eq 1
            expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
          end

          context 'when the broker returns 410 for a service instance fetch request' do
            before do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

              stub_request(:get, service_broker_url).
                to_return(status: 410, body: {}.to_json)
            end

            it 'updates the service instance operation to indicate it has failed' do
              Timecop.freeze(Time.now + 5.minutes) do
                expect(Delayed::Worker.new.work_off).to eq([1, 0])
              end

              service_instance.reload
              expect(service_instance.last_operation.state).to eq('failed')
            end
          end

          context 'when the broker successfully updates the service instance for a service instance fetch request' do
            before do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

              stub_request(:get, service_broker_url).
                to_return(status: 200, body: {
                    last_operation: {
                      state: 'succeeded',
                      description: 'Phew, all done'
                    }
                  }.to_json)
            end

            it 'updates the description of the service instance last operation' do
              Delayed::Job.last.invoke_job

              expect(service_instance.last_operation.reload.state).to eq('succeeded')
              expect(service_instance.last_operation.reload.description).to eq('Phew, all done')
            end

            it 'creates a service audit event for updating the service instance' do
              Timecop.freeze(Time.now + 5.minutes) do
                expect(Delayed::Worker.new.work_off).to eq([1, 0])
              end

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

          context 'when the request is to update the instance to the plan it already has' do
            let(:body) do
              MultiJson.dump(
                service_plan_guid: old_service_plan.guid
              )
            end

            it 'does not make a request to the broker' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

              expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
            end

            it 'marks last_operation state as `succeeded`' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

              expect(service_instance.last_operation.reload.state).to eq 'succeeded'
              expect(service_instance.last_operation.reload.description).to be_nil
            end
          end
        end

        context 'when the request is a service instance rename' do
          let(:status) { 200 }
          let(:body) do
            MultiJson.dump(
              name: 'new-name'
            )
          end
          let(:last_operation) { ServiceInstanceOperation.make(state: 'succeeded') }
          let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }

          before do
            service_instance.service_instance_operation = last_operation
            service_instance.save
          end

          it 'updates service instance name in the database' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

            expect(service_instance.reload.name).to eq('new-name')
          end

          it 'updates operation status to succeeded in the database' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

            expect(service_instance.reload.last_operation.state).to eq('succeeded')
          end
        end

        context 'when the request is to update the instance to the plan it already has' do
          let(:body) do
            MultiJson.dump(
              service_plan_guid: old_service_plan.guid
            )
          end

          it 'does not make a request to the broker' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

            expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
          end

          it 'marks last_operation state as `succeeded`' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(admin_user, email: 'admin@example.com')

            expect(service_instance.last_operation.reload.state).to eq 'succeeded'
            expect(service_instance.last_operation.reload.description).to be_nil
          end
        end

        describe 'error cases' do
          context 'when the service instance has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
            before do
              service_instance.service_instance_operation = last_operation
              service_instance.save
            end

            it 'should show an error message for update operation' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(last_response).to have_status_code 400
              expect(last_response.body).to match 'ServiceInstanceOperationInProgress'
            end
          end

          describe 'concurrent requests' do
            it 'succeeds for exactly one request' do
              stub_request(:patch, "#{service_broker_url}?accepts_incomplete=true").to_return do |_|
                put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
                expect(last_response).to have_status_code 400
                expect(last_response.body).to match /ServiceInstanceOperationInProgress/

                { status: 202, body: {}.to_json }
              end.times(1).then.to_return do |_|
                { status: 202, body: {}.to_json }
              end

              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(last_response).to have_status_code 202
            end
          end

          context 'when the broker did not declare support for plan upgrades' do
            let(:old_service_plan) { ServicePlan.make(:v2) }

            before { service.update(plan_updateable: false) }

            it 'does not update the service plan in the database' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end

            it 'does not make an api call when the plan does not support upgrades' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
            end

            it 'returns a useful error to the user' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(last_response.body).to match /The service does not support changing plans/
            end
          end

          context 'when the user has read but not write permissions' do
            let(:auditor) { User.make }

            before do
              service_instance.space.organization.add_auditor(auditor)
            end

            it 'does not call out to the service broker' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, headers_for(auditor)
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
            end
          end

          context 'when the requested plan does not exist' do
            let(:body) do
              MultiJson.dump(
                service_plan_guid: 'some-non-existing-plan'
              )
            end

            it 'returns an InvalidRelationError' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers
              expect(last_response.status).to eq 400
              expect(last_response.body).to match 'InvalidRelation'
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end
          end

          context 'when the broker client returns an error as its second return value' do
            let(:response_body) { '{"description": "error message"}' }

            before do
              stub_request(:patch,  "#{service_broker_url}?accepts_incomplete=true").
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 500, body: response_body, headers: { 'Content-Type' => 'application/json' })
            end

            it 'saves the attributes provided by the first return value' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

              expect(service_instance.last_operation.state).to eq 'failed'
              expect(service_instance.last_operation.type).to eq 'update'
              expect(service_instance.last_operation.description).to eq 'Service broker error: error message'
            end

            it 're-raises the error' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body, admin_headers

              expect(last_response).to have_status_code 502
            end
          end
        end

        describe 'and the space_guid is provided' do
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

            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", move_req, json_headers(headers_for(user))

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match /Cannot update space for service instance/
          end

          it 'succeeds when the space_guid does not change' do
            req = MultiJson.dump(space_guid: instance.space.guid)
            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", req, json_headers(headers_for(user))
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end

          it 'succeeds when the space_guid is not provided' do
            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", {}.to_json, json_headers(headers_for(user))
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end
        end
      end

      context 'when accepts_incomplete is not true or false strings' do
        it 'fails with with InvalidRequest' do
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=lol", body, admin_headers

          expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
          expect(a_request(:delete, service_broker_url)).to have_been_made.times(0)
          expect(last_response).to have_status_code(400)
        end
      end
    end

    describe 'PUT', '/v2/service_plans/:service_plan_guid/services_instances' do
      let(:first_service_plan)  { ServicePlan.make(:v2) }
      let(:second_service_plan) { ServicePlan.make(:v2) }
      let(:third_service_plan)  { ServicePlan.make(:v2) }
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
        let(:service_plan) { ServicePlan.make(:v2, service: service) }
        let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
        let(:body) { '{}' }
        let(:status) { 200 }

        before do
          stub_deprovision(service_instance, body: body, status: status)
        end

        it 'deletes the service instance with the given guid' do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          }.to change(ServiceInstance, :count).by(-1)
          expect(last_response.status).to eq(204)
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end

        it 'creates a service audit event for deleting the service instance' do
          delete "/v2/service_instances/#{service_instance.guid}", {}, headers_for(admin_user, email: 'admin@example.com')

          expect(last_response).to have_status_code 204

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

        context 'when the instance has bindings' do
          let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

          before do
            stub_unbind(service_binding)
          end

          it 'does not delete the associated service bindings' do
            expect {
              delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
            }.to change(ServiceBinding, :count).by(0)
            expect(ServiceInstance.find(guid: service_instance.guid)).to be
            expect(ServiceBinding.find(guid: service_binding.guid)).to be
          end

          it 'should give the user an error' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(last_response).to have_status_code 400
            expect(last_response.body).to match /AssociationNotEmpty/
            expect(last_response.body).to match /Please delete the service_bindings associations for your service_instances/
          end

          context 'and recursive=true' do
            it 'deletes the associated service bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true", {}, admin_headers
              }.to change(ServiceBinding, :count).by(-1)
              expect(last_response.status).to eq(204)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
            end
          end
        end

        context 'with ?accepts_incomplete=true' do
          before do
            stub_deprovision(service_instance, body: body, status: status, accepts_incomplete: true)
          end

          describe 'concurrent requests' do
            it 'succeeds for exactly one of the requests' do
              stub_deprovision(service_instance, accepts_incomplete: true) do |req|
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, admin_headers
                expect(last_response).to have_status_code 400
                expect(last_response.body).to match /ServiceInstanceOperationInProgress/

                { status: 202, body: {}.to_json }
              end.times(1).then.to_return do |_|
                { status: 202, body: {}.to_json }
              end

              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, admin_headers
              expect(last_response).to have_status_code 202
            end
          end

          context 'when the broker returns a 202' do
            let(:status) { 202 }
            let(:body) do
              {}.to_json
            end

            let(:service_broker_url) do
              broker = service_instance.service_plan.service.service_broker
              broker_uri = URI.parse(broker.broker_url)
              broker_uri.user = broker.auth_username
              broker_uri.password = broker.auth_password
              "#{broker_uri}/v2/service_instances/#{service_instance.guid}"
            end

            it 'should not create a delete event' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(Event.find(type: 'audit.service_instance.delete')).to be_nil
            end

            it 'should create a delete event after the polling finishes' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              broker = service_instance.service_plan.service.service_broker
              broker_uri = URI.parse(broker.broker_url)
              broker_uri.user = broker.auth_username
              broker_uri.password = broker.auth_password
              stub_request(:get, "#{broker_uri}/v2/service_instances/#{service_instance.guid}").
                to_return(status: 200, body: {
                  last_operation: {
                    state: 'succeeded',
                    description: 'Done!'
                  }
                }.to_json)

              Timecop.freeze Time.now + 2.minute do
                Delayed::Job.last.invoke_job
                expect(Event.find(type: 'audit.service_instance.delete')).to be
              end
            end

            it 'indicates the service instance is being deleted' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(last_response).to have_status_code 202
              expect(service_instance.last_operation.state).to eq 'in progress'

              expect(ManagedServiceInstance.last.last_operation.type).to eq('delete')
              expect(ManagedServiceInstance.last.last_operation.state).to eq('in progress')

              expect(decoded_response['entity']['last_operation']).to be
              expect(decoded_response['entity']['last_operation']['type']).to eq('delete')
              expect(decoded_response['entity']['last_operation']['state']).to eq('in progress')
            end

            it 'enqueues a polling job to fetch state from the broker' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')
              stub_request(:get, service_broker_url).
                to_return(status: 200, body: {
                  last_operation: {
                    state: 'in progress',
                    description: 'Yep, still working'
                  }
                }.to_json)

              expect(last_response).to have_status_code 202
              Timecop.freeze Time.now + 30.minutes do
                expect(Delayed::Worker.new.work_off).to eq [1, 0]
              end
            end

            context 'when the broker successfully fetches updated information about the instance' do
              before do
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')
                stub_request(:get, service_broker_url).
                  to_return(status: 200, body: {
                      last_operation: {
                        state: 'in progress',
                        description: 'still going'
                      }
                    }.to_json)
              end

              it 'updates the description of the service instance last operation' do
                Delayed::Job.last.invoke_job

                expect(service_instance.last_operation.reload.state).to eq('in progress')
                expect(service_instance.last_operation.reload.description).to eq('still going')
              end
            end
          end

          context 'when the broker returns 200' do
            let(:status) { 200 }
            let(:body) do
              {}.to_json
            end

            it 'remove the service instance' do
              service_instance_guid = service_instance.guid
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(last_response).to have_status_code(204)
              expect(ManagedServiceInstance.find(guid: service_instance_guid)).to be_nil
            end

            context 'and with ?async=true' do
              it 'gives accepts_incomplete precedence and deletes the instance synchronously', isolation: :truncation do
                service_instance_guid = service_instance.guid
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true&async=true", {}, headers_for(admin_user, email: 'admin@example.com')

                expect(last_response).to have_status_code(204)
                expect(ManagedServiceInstance.find(guid: service_instance_guid)).to be_nil
              end
            end
          end

          context 'when the broker returns a 400' do
            let(:status) { 400 }
            let(:body) do
              {
                description: 'fake-description'
              }.to_json
            end

            it 'fails the initial delete' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(last_response).to have_status_code 502
              expect(decoded_response['description']).to eq("Service broker error: #{MultiJson.load(body)['description']}")
            end
          end

          context 'when broker returns 5xx with a top-level description' do
            let(:status) { 500 }
            let(:body) do
              {
                description: 'fake-description'
              }.to_json
            end

            it 'fails the initial delete with description included in the error message' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(last_response).to have_status_code 502
              expect(decoded_response['description']).to eq("Service broker error: #{MultiJson.load(body)['description']}")
            end
          end

          context 'when broker returns times out' do
            let(:status) { 408 }
            let(:body) do
              {}.to_json
            end

            before do
              stub_request(:delete, service_broker_url_regex).
                with(headers: { 'Accept' => 'application/json' }).
                  to_raise(HTTPClient::TimeoutError)
            end

            it 'fails the initial delete with description included in the error message' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers_for(admin_user, email: 'admin@example.com')

              expect(last_response).to have_status_code 504

              response_description = "The request to the service broker timed out: #{service.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}"
              expect(decoded_response['description']).to eq(response_description)
            end
          end
        end

        context 'with ?async=true & accepts_incomplete=false' do
          it 'returns a job id' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, admin_headers
            expect(last_response).to have_status_code 202
            expect(decoded_response['entity']['guid']).to be
            expect(decoded_response['entity']['status']).to eq 'queued'

            successes, failures = Delayed::Worker.new.work_off
            expect(successes).to eq 1
            expect(failures).to eq 0
            expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
          end

          it 'creates a service audit event for deleting the service instance' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, headers_for(admin_user, email: 'admin@example.com')
            expect(last_response).to have_status_code 202

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
            expect(event).to be_nil

            expect(Delayed::Worker.new.work_off).to eq([1, 0])

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

          it 'does not get stuck in progress if the service instance is delete synchronously before the job runs' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, admin_headers
            expect(last_response).to have_status_code 202

            job_url = decoded_response['metadata']['url']

            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
            expect(last_response).to have_status_code 204

            Delayed::Worker.new.work_off

            get job_url, {}, admin_headers
            expect(decoded_response['entity']['status']).to eq 'finished'
          end

          context 'when the instance has an operation in progress' do
            it 'succeeds for exactly one of the requests' do
              delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, admin_headers
              expect(last_response).to have_status_code 202

              stub_deprovision(service_instance) do |_|
                job = Delayed::Job.first
                expect { job.invoke_job }.to raise_error(VCAP::Errors::ApiError)

                { status: 202, body: {}.to_json }
              end.times(1).then.to_return do |_|
                { status: 202, body: {}.to_json }
              end

              delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
              expect(last_response).to have_status_code 204
            end
          end

          context 'when the service broker returns 500' do
            let(:status) { 500 }

            it 'enqueues the standard ModelDeletion job which marks the state as failed' do
              service_instance_guid = service_instance.guid
              delete "/v2/service_instances/#{service_instance.guid}?async=true", {}, admin_headers

              expect(last_response).to have_status_code 202
              expect(decoded_response['entity']['status']).to eq 'queued'

              successes, failures = Delayed::Worker.new.work_off
              expect(successes + failures).to eq 1

              service_instance = ServiceInstance.find(guid: service_instance_guid)
              expect(service_instance).to be
              expect(service_instance.last_operation.type).to eq 'delete'
              expect(service_instance.last_operation.state).to eq 'failed'
            end
          end
        end

        context 'and the service broker returns a 409' do
          let(:body) { '{"description": "service broker error"}' }
          let(:status) { 409 }

          it 'it returns a CF-ServiceBrokerBadResponse error' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerBadResponse'
            expect(JSON.parse(last_response.body)['description']).to include 'service broker error'
          end
        end

        context 'and the instance cannot be found' do
          it 'returns a 404' do
            delete '/v2/service_instances/non-existing-instance', {}, admin_headers
            expect(last_response.status).to eq 404
          end
        end

        context 'and the instance operation is in progress' do
          let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
          before do
            service_instance.service_instance_operation = last_operation
          end

          it 'should show an error message for delete operation' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
            expect(last_response.status).to eq 400
            expect(last_response.body).to match 'ServiceInstanceOperationInProgress'
          end
        end
      end

      context 'with a v1 service instance' do
        let(:service) { Service.make(:v1) }
        let(:service_plan) { ServicePlan.make(:v1, service: service) }
        let!(:service_instance) { ManagedServiceInstance.make(:v1, service_plan: service_plan) }

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

        it 'deletes the service instance with the given guid' do
          delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
          expect(last_response).to have_status_code 204
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end

        context 'when the instance has bindings' do
          let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

          it 'does not delete the associated service bindings' do
            expect {
              delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers
            }.to change(ServiceBinding, :count).by(0)
            expect(ServiceInstance.find(guid: service_instance.guid)).to be
            expect(ServiceBinding.find(guid: service_binding.guid)).to be
          end

          it 'should give the user an error' do
            delete "/v2/service_instances/#{service_instance.guid}", {}, admin_headers

            expect(last_response).to have_status_code 400
            expect(last_response.body).to match /AssociationNotEmpty/
            expect(last_response.body).to match /Please delete the service_bindings associations for your service_instances/
          end

          context 'when recursive=true' do
            it 'deletes the associated service bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true", {}, admin_headers
              }.to change(ServiceBinding, :count).by(-1)
              expect(last_response.status).to eq(204)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
            end
          end
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

    describe 'GET', '/v2/service_instances/:service_instance_guid/service_keys' do
      let(:space)   { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when the user is not a member of the space this instance exists in' do
        let(:space_a)   { Space.make }
        let(:instance)  { ManagedServiceInstance.make(space: space_a) }

        it 'returns the forbidden code' do
          get "/v2/service_instances/#{instance.guid}/service_keys", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(403)
        end
      end

      context 'when the user is a member of the space this instance exists in' do
        let(:instance_a)  { ManagedServiceInstance.make(space: space) }
        let(:instance_b)  { ManagedServiceInstance.make(space: space) }
        let(:service_key_a) { ServiceKey.make(name: 'fake-key-a', service_instance: instance_a) }
        let(:service_key_b) { ServiceKey.make(name: 'fake-key-b', service_instance: instance_a) }
        let(:service_key_c) { ServiceKey.make(name: 'fake-key-c', service_instance: instance_b) }

        before do
          service_key_a.save
          service_key_b.save
          service_key_c.save
        end

        it 'returns the service keys that belong to the service instance' do
          get "/v2/service_instances/#{instance_a.guid}/service_keys", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(decoded_response.fetch('total_results')).to eq(2)
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_a.guid)
          expect(decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')).to eq(service_key_b.guid)

          get "/v2/service_instances/#{instance_b.guid}/service_keys", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(decoded_response.fetch('total_results')).to eq(1)
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_c.guid)
        end

        it 'returns the service keys filtered by key name' do
          get "/v2/service_instances/#{instance_a.guid}/service_keys?q=name:fake-key-a", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(decoded_response.fetch('total_results')).to eq(1)
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_a.guid)

          get "/v2/service_instances/#{instance_b.guid}/service_keys?q=name:non-exist-key-name", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          expect(decoded_response.fetch('total_results')).to eq(0)
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
      let(:paid_plan) { ServicePlan.make(:v2) }
      let(:free_plan) { ServicePlan.make(:v2, free: true) }
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
          plan = ServicePlan.make(:v2, free: true)

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
      arbitrary_params = user_opts.delete(:parameters)
      accepts_incomplete = user_opts.delete(:accepts_incomplete) { |_| 'true' }
      headers = json_headers(headers_for(developer, user_opts))

      body = {
        name: 'foo',
        space_guid: space.guid,
        service_plan_guid: plan.guid,
      }
      body[:parameters] = arbitrary_params if arbitrary_params
      req = MultiJson.dump(body)

      if accepts_incomplete
        post "/v2/service_instances?accepts_incomplete=#{accepts_incomplete}", req, headers
      else
        post '/v2/service_instances', req, headers
      end

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
