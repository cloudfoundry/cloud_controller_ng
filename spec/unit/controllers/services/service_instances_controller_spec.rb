require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ServiceInstancesController, :services do
    let(:service_broker_url_regex) { %r{http://auth_username:auth_password@example.com/v2/service_instances/(.*)} }
    let(:mock_orphan_mitigator) { double(:mock_orphan_mitigator, attempt_deprovision_instance: nil) }
    let(:logger) { double(:logger) }

    describe 'Query Parameters' do
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:name) }
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:space_guid) }
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:service_plan_guid) }
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:service_binding_guid) }
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:gateway_name) }
      it { expect(VCAP::CloudController::ServiceInstancesController).to be_queryable_by(:organization_guid) }
    end

    describe 'Attributes' do
      it 'has creatable attributes' do
        expect(VCAP::CloudController::ServiceInstancesController).to have_creatable_attributes({
          name: { type: 'string', required: true },
          space_guid: { type: 'string', required: true },
          service_plan_guid: { type: 'string', required: true },
          service_key_guids: { type: '[string]' },
          tags: { type: '[string]', default: [] },
          parameters: { type: 'hash', default: nil },
        })
      end

      it 'has updatable attributes' do
        expect(VCAP::CloudController::ServiceInstancesController).to have_updatable_attributes({
          name: { type: 'string' },
          space_guid: { type: 'string' },
          service_plan_guid: { type: 'string' },
          service_key_guids: { type: '[string]' },
          tags: { type: '[string]' },
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
        user_sees_empty_enumerate('OrgUser',        :@org_a_member,          :@org_b_member)
        user_sees_empty_enumerate('BillingManager', :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate('Auditor',        :@org_a_auditor,         :@org_b_auditor)

        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name: 'managed service instance',
            path: '/v2/service_instances',
            enumerate: 1
        end
      end

      describe 'App Space Level Permissions' do
        let(:service_broker_url_regex) do
          uri = URI(broker.broker_url)
          broker_url = uri.host + uri.path
          %r{https://#{broker.auth_username}:#{broker.auth_password}@#{broker_url}/v2/service_instances/(.*)}
        end

        describe 'plans from a private broker' do
          let(:space) { Space.make }
          let(:organization) { space.organization }
          let!(:private_broker) { ServiceBroker.make(space_guid: space.guid) }
          let!(:service_from_a_private_broker) { Service.make(service_broker: private_broker) }
          let!(:plan_from_a_private_broker) { ServicePlan.make(service: service_from_a_private_broker, public: false) }
          let(:broker) { private_broker }
          let!(:developer) { make_developer_for_space(space) }

          before do
            stub_request(:put, service_broker_url_regex).
              with(headers: { 'Accept' => 'application/json' }).
              to_return(
                status: 201,
                body: { dashboard_url: 'url.com', state: 'succeeded', state_description: '100%' }.to_json,
                headers: { 'Content-Type' => 'application/json' })
            set_current_user(developer)
          end

          it 'allows a user to create a service instance for a private broker in the same space as the broker' do
            payload = MultiJson.dump(
              'space_guid' => space.guid,
              'name' => Sham.name,
              'service_plan_guid' => plan_from_a_private_broker.guid,
            )

            post 'v2/service_instances', payload
            expect(last_response.status).to eq(201)
          end

          it 'does not allow user to create a service instance for a private broker in a difference space as the broker' do
            other_space = Space.make organization: organization
            other_space.add_developer developer

            payload = MultiJson.dump(
              'space_guid' => other_space.guid,
              'name' => Sham.name,
              'service_plan_guid' => plan_from_a_private_broker.guid,
            )

            post 'v2/service_instances', payload
            expect(last_response.status).to eq(403)
            expect(parsed_response['description']).to match('A service instance for the selected plan cannot be created in this space.')
          end
        end

        describe 'plans with public:false' do
          let!(:unprivileged_organization) { Organization.make }
          let!(:private_plan) { ServicePlan.make(:v2, public: false) }
          let!(:unprivileged_space) { Space.make(organization: unprivileged_organization) }
          let!(:developer) { make_developer_for_space(unprivileged_space) }
          let(:broker) { private_plan.service_broker }

          before do
            stub_request(:put, service_broker_url_regex).
              with(headers: { 'Accept' => 'application/json' }).
              to_return(
                status: 201,
                body: { dashboard_url: 'url.com', state: 'succeeded', state_description: '100%' }.to_json,
                headers: { 'Content-Type' => 'application/json' })
            set_current_user(developer)
          end

          describe 'a user who does not belong to a privileged organization' do
            it 'does not allow a user to create a service instance' do
              payload = MultiJson.dump(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload

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
              set_current_user(developer)
            end

            let(:broker) { private_plan.service.service_broker }
            let(:service_broker_url_regex) do
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

              post 'v2/service_instances', payload
              expect(last_response.status).to eq(201)
            end

            it 'does not allow a user to create a service instance in an unprivileged organization' do
              payload = MultiJson.dump(
                'space_guid' => unprivileged_space.guid,
                'name' => Sham.name,
                'service_plan_guid' => private_plan.guid,
              )

              post 'v2/service_instances', payload

              expect(last_response.status).to eq(403)
              expect(MultiJson.load(last_response.body)['description']).to match('A service instance for the selected plan cannot be created in this organization.')
            end
          end
        end

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

            set_current_user(member_a)
            post '/v2/service_instances', req

            expect(last_response.status).to eq(403)
            expect(MultiJson.load(last_response.body)['description']).to eq('You are not authorized to perform the requested action')
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

        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name: 'managed service instance',
            path: '/v2/service_instances',
            enumerate: 1
        end
      end
    end

    describe 'Associations' do
      it do
        expect(VCAP::CloudController::ServiceInstancesController).to have_nested_routes(
          service_bindings: [:get],
          service_keys: [:get, :put, :delete],
          routes: [:get, :put, :delete]
        )
      end
    end

    describe 'POST /v2/service_instances' do
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
          set_current_user(developer)
        end

        it 'provisions a service instance' do
          instance = create_managed_service_instance(accepts_incomplete: 'false')

          expect(last_response).to have_status_code(201)
          expect(last_response.headers['Location']).to eq "/v2/service_instances/#{instance.guid}"

          expect(instance.credentials).to eq({})
          expect(instance.dashboard_url).to eq('the dashboard_url')
          last_operation = decoded_response['entity']['last_operation']
          expect(last_operation['state']).to eq 'succeeded'
          expect(last_operation['description']).to eq ''
          expect(last_operation['type']).to eq 'create'
        end

        it 'creates a CREATED service usage event' do
          instance = nil
          expect {
            instance = create_managed_service_instance(accepts_incomplete: 'false')
          }.to change { ServiceUsageEvent.count }.by(1)

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::ServiceUsageEventRepository::CREATED_EVENT_STATE)
          expect(event).to match_service_instance(instance)
        end

        context 'when the catalog response includes services that require route forwarding' do
          let(:service) { Service.make(:routing, service_broker: service_broker) }
          let(:plan) { ServicePlan.make(:v2, service: service) }

          context 'when route service is disabled' do
            before do
              TestConfig.config[:route_services_enabled] = false
            end

            it 'should succeed with a warning' do
              instance = create_managed_service_instance(accepts_incomplete: 'false')

              expect(last_response).to have_status_code(201)
              expect(last_response.headers['Location']).to eq "/v2/service_instances/#{instance.guid}"

              expect(instance.credentials).to eq({})
              expect(instance.dashboard_url).to eq('the dashboard_url')
              last_operation = decoded_response['entity']['last_operation']
              expect(last_operation['state']).to eq 'succeeded'
              expect(last_operation['description']).to eq ''
              expect(last_operation['type']).to eq 'create'

              escaped_warning = last_response.headers['X-Cf-Warnings']
              expect(escaped_warning).to_not be_nil
              warning = CGI.unescape(escaped_warning)
              expect(warning).to match /Support for route services is disabled. This service instance cannot be bound to a route./
            end
          end

          context 'when route service is enabled' do
            before do
              TestConfig.config['route_services_enabled'] = true
            end

            it 'should succeed without warnings' do
              instance = create_managed_service_instance(accepts_incomplete: 'false')

              expect(last_response).to have_status_code(201)
              expect(last_response.headers['Location']).to eq "/v2/service_instances/#{instance.guid}"

              expect(instance.credentials).to eq({})
              expect(instance.dashboard_url).to eq('the dashboard_url')
              last_operation = decoded_response['entity']['last_operation']
              expect(last_operation['state']).to eq 'succeeded'
              expect(last_operation['description']).to eq ''
              expect(last_operation['type']).to eq 'create'

              warning = last_response.headers['X-Cf-Warnings']
              expect(warning).to be_nil
            end
          end
        end

        context 'when the catalog response includes services that require volume mounts' do
          let(:service) { Service.make(:volume_mount, service_broker: service_broker) }
          let(:plan) { ServicePlan.make(:v2, service: service) }

          context 'when volume mounts service is disabled' do
            before do
              TestConfig.config[:volume_services_enabled] = false
            end

            it 'should succeed with a warning' do
              instance = create_managed_service_instance(accepts_incomplete: 'false')

              expect(last_response).to have_status_code(201)
              expect(last_response.headers['Location']).to eq "/v2/service_instances/#{instance.guid}"

              expect(instance.credentials).to eq({})
              expect(instance.dashboard_url).to eq('the dashboard_url')
              last_operation = decoded_response['entity']['last_operation']
              expect(last_operation['state']).to eq 'succeeded'
              expect(last_operation['description']).to eq ''
              expect(last_operation['type']).to eq 'create'

              escaped_warning = last_response.headers['X-Cf-Warnings']
              expect(escaped_warning).to_not be_nil
              warning = CGI.unescape(escaped_warning)
              expect(warning).to match /Support for volume services is disabled. This service instance cannot be bound to an app./
            end
          end

          context 'when volume mounts service is enabled' do
            before do
              TestConfig.config[:volume_services_enabled] = true
            end

            it 'should succeed without warnings' do
              instance = create_managed_service_instance(accepts_incomplete: 'false')

              expect(last_response).to have_status_code(201)
              expect(last_response.headers['Location']).to eq "/v2/service_instances/#{instance.guid}"

              expect(instance.credentials).to eq({})
              expect(instance.dashboard_url).to eq('the dashboard_url')
              last_operation = decoded_response['entity']['last_operation']
              expect(last_operation['state']).to eq 'succeeded'
              expect(last_operation['description']).to eq ''
              expect(last_operation['type']).to eq 'create'

              warning = last_response.headers['X-Cf-Warnings']
              expect(warning).to be_nil
            end
          end
        end

        describe 'instance tags' do
          context 'when service instance tags are sent with the create request' do
            it 'saves the service instance tags' do
              tags = %w(a b c)
              new_instance = create_managed_service_instance(
                email: 'developer@example.com',
                accepts_incomplete: false,
                tags: tags
              )

              expect(last_response).to have_status_code 201
              expect(decoded_response['entity']['tags']).to eq tags

              expect(new_instance.tags).to eq tags
            end
          end

          context 'when no service instance tags are sent with the create request' do
            it 'saves no service instance tags' do
              new_instance = create_managed_service_instance(
                email: 'developer@example.com',
                accepts_incomplete: false,
              )

              expect(last_response).to have_status_code 201
              expect(decoded_response['entity']['tags']).to eq([])

              expect(new_instance.tags).to eq([])
            end
          end
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
              expect(last_response.body).to include('Error: Expected instance of Hash')
            end
          end
        end

        context 'when the client does not support accepts_incomplete parameter' do
          let(:response_body) do
            {}.to_json
          end

          it 'creates a service audit event for creating the service instance' do
            set_current_user(developer, email: 'developer@example.com')
            instance = create_managed_service_instance(accepts_incomplete: false)

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
            expect(event.organization_guid).to eq(instance.space.organization.guid)
            expect(event.metadata['request']).to include({
              'name' => instance.name,
              'service_plan_guid' => instance.service_plan_guid,
              'space_guid' => instance.space_guid,
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
              allow(SynchronousOrphanMitigate).to receive(:new).and_return(mock_orphan_mitigator)
              allow(logger).to receive(:error)
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

          context 'when the service broker returns operation state' do
            let(:response_body) do
              { operation: '8edff4d8-2818-11e6-a53f-685b3585cc4e' }.to_json
            end

            it 'persists the operation state' do
              service_instance = create_managed_service_instance

              expect(last_response).to have_status_code(202)
              expect(service_instance.last_operation.state).to eq('in progress')
              expect(service_instance.last_operation.broker_provided_operation).to eq('8edff4d8-2818-11e6-a53f-685b3585cc4e')
            end
          end

          it 'immediately enqueues a fetch job' do
            Timecop.freeze do
              create_managed_service_instance
              job = Delayed::Job.last
              poll_interval = VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds).seconds
              expect(job.run_at).to be < Time.now.utc + poll_interval
            end
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
            let(:service_broker_last_operation_url) { "http://auth_username:auth_password@example.com/v2/service_instances/#{ServiceInstance.last.guid}/last_operation" }

            before do
              stub_request(:get, service_broker_url_regex).
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 200, body: {
                  state: 'succeeded',
                  description: 'new description'
                }.to_json)
            end

            it 'updates the description of the service instance last operation' do
              service_instance = create_managed_service_instance(email: 'developer@example.com')

              Delayed::Job.last.invoke_job

              expect(service_instance.last_operation.reload.state).to eq('succeeded')
              expect(service_instance.last_operation.reload.description).to eq('new description')
            end

            context 'broker supplied a operation field' do
              let(:response_body) do
                { operation: '8edff4d8-2818-11e6-a53f-685b3585cc4e' }.to_json
              end

              it 'invokes last operation with the broker provided operation' do
                create_managed_service_instance(email: 'developer@example.com')

                Delayed::Job.last.invoke_job

                expect(a_request(:get, service_broker_last_operation_url).with(query: hash_including({ 'operation' => '8edff4d8-2818-11e6-a53f-685b3585cc4e' }))).to have_been_made
              end
            end

            it 'creates an audit event' do
              set_current_user(developer, email: 'developer@example.com')
              instance = create_managed_service_instance

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
              expect(event.organization_guid).to eq(instance.space.organization.guid)
              expect(event.metadata['request']).to include({
                'name' => instance.name,
                'service_plan_guid' => instance.service_plan_guid,
                'space_guid' => instance.space_guid,
              })
            end
          end

          context 'and the worker never gets a success response during polling' do
            let!(:now) { Time.now }
            let(:max_poll_duration) { VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes) }
            let(:before_poll_timeout) { now + (max_poll_duration / 2).minutes }
            let(:after_poll_timeout) { now + max_poll_duration.minutes + 1.minutes }

            before do
              stub_request(:get, service_broker_url_regex).
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 200, body: {
                  state: 'in progress',
                  description: 'new description'
                }.to_json)
            end

            it 'does not enqueue additional delay_jobs after broker_client_max_async_poll_duration_minutes' do
              service_instance_guid = nil
              Timecop.freeze now do
                create_managed_service_instance
                service_instance_guid = decoded_response['metadata']['guid']
              end

              Timecop.travel(before_poll_timeout) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(Delayed::Job.count).to eq 1
              end

              Timecop.travel(after_poll_timeout) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(Delayed::Job.count).to eq 0
              end

              get "/v2/service_instances/#{service_instance_guid}"
              expect(last_response).to have_status_code 200
              expect(decoded_response['entity']['last_operation']['state']).to eq 'failed'
              expect(decoded_response['entity']['last_operation']['description']).to match /Service Broker failed to provision within the required time/
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
            set_current_user(developer, email: 'developer@example.com')
            instance = create_managed_service_instance(accepts_incomplete: 'false')

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
            expect(event.organization_guid).to eq(instance.space.organization.guid)
            expect(event.metadata['request']).to include({
              'name' => instance.name,
              'service_plan_guid' => instance.service_plan_guid,
              'space_guid' => instance.space_guid,
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
          let(:mock_orphan_mitigator) { double(:mock_orphan_mitigator, attempt_deprovision_instance: nil) }
          let(:body) do
            {
              dashboard_url: 'http://example-dashboard.com/9189kdfsk0vfnku',
            }.to_json
          end

          before do
            allow(SynchronousOrphanMitigate).to receive(:new).and_return(mock_orphan_mitigator)
            allow(logger).to receive(:error)
          end

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

          it 'returns a name validation error' do
            post '/v2/service_instances', body

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq 60001
          end

          it 'does not provision or deprovision an instance' do
            post '/v2/service_instances', body

            expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(0)
            expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(0)
          end

          it 'does not create a service instance' do
            expect {
              post '/v2/service_instances', body
            }.to_not change(ServiceInstance, :count)
          end
        end

        context 'when the model save and the subsequent deprovision both raise errors' do
          let(:save_error_text) { 'InvalidRequest' }
          let(:deprovision_error_text) { 'NotAuthorized' }

          before do
            stub_delete_and_return(403, '{}')
            allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise(CloudController::Errors::ApiError.new_from_details(save_error_text))
          end

          it 'raises the save error' do
            req = MultiJson.dump(
              name: 'foo',
              space_guid: space.guid,
              service_plan_guid: plan.guid
            )

            post '/v2/service_instances', req

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

            post '/v2/service_instances', req

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

            post '/v2/service_instances', req
          end

          it 'returns a 400' do
            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('not a valid service plan')
            expect(decoded_response['code']).to eq(60003)
          end
        end

        describe 'orphan mitigation' do
          let(:delete_request_status) { 200 }
          before do
            stub_delete_and_return(delete_request_status, '{}')
          end

          context 'when the broker returns an error' do
            let(:response_code) { 500 }
            let(:req) do
              MultiJson.dump(
                name: 'foo',
                space_guid: space.guid,
                service_plan_guid: plan.guid
              )
            end

            before do
              allow(SynchronousOrphanMitigate).to receive(:new).and_return(mock_orphan_mitigator)
              allow(logger).to receive(:error)
            end

            it 'mitigates orphans by deprovisioning the instance' do
              post '/v2/service_instances', req

              expect(last_response.status).to eq(502)
              expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(1)
              expect(a_request(:delete, service_broker_url_regex)).not_to have_been_made.times(1)

              orphan_mitigation_job = Delayed::Job.first
              expect(orphan_mitigation_job).not_to be_nil
              expect(orphan_mitigation_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedInstance

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(1)
            end

            context 'and the broker returns a 202 for the follow up deletion request' do
              let(:delete_request_status) { 202 }

              before do
                allow(SynchronousOrphanMitigate).to receive(:new).and_return(mock_orphan_mitigator)
                allow(logger).to receive(:error)
              end

              it 'treats the 202 as a successful deletion and does not poll the last_operation endpoint' do
                post '/v2/service_instances', req

                expect(last_response.status).to eq(502)
                expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(1)
                expect(a_request(:delete, service_broker_url_regex)).not_to have_been_made.times(1)

                orphan_mitigation_job = Delayed::Job.first
                expect(orphan_mitigation_job).not_to be_nil
                expect(orphan_mitigation_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedInstance

                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(1)
                expect(a_request(:get, %r{#{service_broker_url_regex}/last_operation})).not_to have_been_made.times(1)

                expect(Delayed::Job.count).to eq 0
              end
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

              post '/v2/service_instances', req

              expect(last_response.status).to eq(500)
              expect(a_request(:put, service_broker_url_regex)).to have_been_made.times(1)
              expect(a_request(:delete, service_broker_url_regex)).to have_been_made.times(1)

              orphan_mitigation_job = Delayed::Job.first
              expect(orphan_mitigation_job).to be_nil
            end
          end
        end
      end
    end

    describe 'GET /v2/service_instances' do
      context 'dashboard_url' do
        let(:service_instance) { ManagedServiceInstance.make(gateway_name: Sham.name) }
        let(:space) { service_instance.space }
        let(:developer) { make_developer_for_space(space) }

        it 'shows the dashboard_url if there is' do
          service_instance.update(dashboard_url: 'http://dashboard.io')
          set_current_user(developer)
          get "v2/service_instances/#{service_instance.guid}"
          expect(decoded_response.fetch('entity').fetch('dashboard_url')).to eq('http://dashboard.io')
        end
      end

      context 'admin' do
        context 'filtering' do
          before { set_current_user_as_admin }

          context 'when filtering by org guid' do
            let(:org1) { Organization.make(guid: '1') }
            let(:org2) { Organization.make(guid: '2') }
            let(:org3) { Organization.make(guid: '3') }
            let(:space1) { Space.make(organization: org1) }
            let(:space2) { Space.make(organization: org2) }
            let(:space3) { Space.make(organization: org3) }

            context 'when the operator is ":"' do
              it 'successfully filters' do
                instance1 = ManagedServiceInstance.make(name: 'instance-1', space: space1)
                ManagedServiceInstance.make(name: 'instance-2', space: space2)

                get "v2/service_instances?q=organization_guid:#{org1.guid}"

                expect(last_response.status).to eq(200)
                expect(decoded_response['resources'].length).to eq(1)
                expect(decoded_response['resources'][0].fetch('metadata').fetch('guid')).to eq(instance1.guid)
              end

              context 'when filtering by other parameters as well' do
                it 'filters by both parameters' do
                  instance1 = ManagedServiceInstance.make(name: 'instance-1', space: space1)
                  ManagedServiceInstance.make(name: 'instance-2', space: space1)
                  ManagedServiceInstance.make(name: instance1.name, space: space2)

                  get "v2/service_instances?q=organization_guid:#{org1.guid}&q=name:#{instance1.name}"

                  expect(last_response.status).to eq(200)
                  resources = decoded_response['resources']
                  expect(resources.length).to eq(1)
                  expect(resources[0].fetch('metadata').fetch('guid')).to eq(instance1.guid)
                end
              end
            end

            context 'when the operator is "IN"' do
              it 'successfully filters' do
                instance1 = ManagedServiceInstance.make(name: 'inst1', space: space1)
                instance2 = ManagedServiceInstance.make(name: 'inst2', space: space2)
                ManagedServiceInstance.make(name: 'inst3', space: space3)

                get "v2/service_instances?q=organization_guid%20IN%20#{org1.guid},#{org2.guid}"

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(2)
                expect(services).to include(instance1.guid)
                expect(services).to include(instance2.guid)
              end
            end

            context 'when the operator is a comparator' do
              let!(:instance1) { ManagedServiceInstance.make(name: 'inst1', space: space1) }
              let!(:instance2) { ManagedServiceInstance.make(name: 'inst2', space: space2) }
              let!(:instance3) { ManagedServiceInstance.make(name: 'inst3', space: space3) }

              it 'successfully filters on <' do
                get "v2/service_instances?q=organization_guid<#{org2.guid}"

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(1)
                expect(services).to include(instance1.guid)
              end

              it 'successfully filters on >' do
                get "v2/service_instances?q=organization_guid>#{org2.guid}"

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(1)
                expect(services).to include(instance3.guid)
              end

              it 'successfully filters on <=' do
                get "v2/service_instances?q=organization_guid<=#{org2.guid}"

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(2)
                expect(services).to include(instance1.guid)
                expect(services).to include(instance2.guid)
              end

              it 'successfully filters on >=' do
                get "v2/service_instances?q=organization_guid>=#{org2.guid}"

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(2)
                expect(services).to include(instance2.guid)
                expect(services).to include(instance3.guid)
              end
            end

            context 'when the query is missing an operator or a value' do
              it 'filters by org_guid = nil (to match behavior of filters other than org guid)' do
                ManagedServiceInstance.make(name: 'instance-1', space: space1)
                ManagedServiceInstance.make(name: 'instance-2', space: space2)

                get 'v2/service_instances?q=organization_guid'

                expect(last_response.status).to eq(200)
                services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(services.length).to eq(0)
              end
            end
          end
        end
      end

      context 'admin_read_only' do
        let!(:instance1) { ManagedServiceInstance.make(name: 'inst1') }
        let!(:instance2) { ManagedServiceInstance.make(name: 'inst2') }

        before { set_current_user_as_admin_read_only }

        it 'list service instances' do
          get 'v2/service_instances'

          expect(last_response.status).to eq(200)
          service_instance_guids = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
          expect(service_instance_guids.length).to eq(2)
          expect(service_instance_guids).to include(instance1.guid, instance2.guid)
        end
      end

      context 'with pagination' do
        before { set_current_user_as_admin }
        let(:results_per_page) { 1 }
        let(:service_instance) { ManagedServiceInstance.make(gateway_name: Sham.name) }
        let(:org1) { Organization.make(guid: '1') }
        let(:org2) { Organization.make(guid: '2') }
        let(:space1) { Space.make(organization: org1) }
        let(:space2) { Space.make(organization: org2) }
        let!(:instances) do
          [ManagedServiceInstance.make(name: 'instance-1', space: space1),
           ManagedServiceInstance.make(name: 'instance-2', space: space1),
           ManagedServiceInstance.make(name: 'instance-3', space: space1),
           ManagedServiceInstance.make(name: 'instance-4', space: space2),
          ]
        end

        context 'at page 1' do
          let(:page) { 1 }
          it 'passes the org_guid filter into the next_url' do
            get "v2/service_instances?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
            expect(last_response.status).to eq(200), last_response.body
            services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
            expect(services.length).to eq(1)
            expect(services).to include(instances[0].guid)
            result = JSON.parse(last_response.body)
            expect(result['next_url']).to include("q=organization_guid:#{org1.guid}"), result['next_url']
            expect(result['prev_url']).to be_nil
          end
        end

        context 'at page 2' do
          let(:page) { 2 }
          it 'passes the org_guid filter into the next_url' do
            get "v2/service_instances?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
            expect(last_response.status).to eq(200), last_response.body
            services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
            expect(services.length).to eq(1)
            expect(services).to include(instances[1].guid)
            result = JSON.parse(last_response.body)
            expect(result['next_url']).to include("q=organization_guid:#{org1.guid}"), result['next_url']
            expect(result['prev_url']).to include("q=organization_guid:#{org1.guid}"), result['prev_url']
          end
        end

        context 'at page 3' do
          let(:page) { 3 }
          it 'passes the org_guid filter into the next_url' do
            get "v2/service_instances?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
            expect(last_response.status).to eq(200), last_response.body
            services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
            expect(services.length).to eq(1)
            expect(services).to include(instances[2].guid)
            result = JSON.parse(last_response.body)
            expect(result['next_url']).to be_nil
            expect(result['prev_url']).to include("q=organization_guid:#{org1.guid}"), result['prev_url']
          end
        end

        context 'at page 4' do
          let(:page) { 4 }
          it 'passes the org_guid filter into the next_url' do
            get "v2/service_instances?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
            expect(last_response.status).to eq(200), last_response.body
            services = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
            expect(services.length).to eq(0)
            result = JSON.parse(last_response.body)
            expect(result['next_url']).to be_nil
            expect(result['prev_url']).to include("q=organization_guid:#{org1.guid}"), result['prev_url']
          end
        end
      end
    end

    describe 'GET /v2/service_instances/:service_instance_guid' do
      let(:space) { service_instance.space }
      let(:developer) { make_developer_for_space(space) }

      context 'with a managed service instance' do
        let(:space) { Space.make }
        let(:service_instance) { ManagedServiceInstance.make(space: space) }
        let(:service_plan) { ServicePlan.make(active: false) }

        before do
          service_instance.dashboard_url = 'this.should.be.visible.com'
          service_instance.service_plan_id = service_plan.id
          service_instance.save
        end

        it 'returns the service instance with the given guid' do
          set_current_user_as_admin
          get "v2/service_instances/#{service_instance.guid}"
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('metadata').fetch('guid')).to eq(service_instance.guid)
        end

        context 'space developer' do
          before do
            set_current_user(developer)
          end

          it 'returns the dashboard url in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('dashboard_url')).to eq('this.should.be.visible.com')
          end

          it 'returns service_plan_guid in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('service_plan_guid')).to eq(service_plan.guid)
          end
        end

        context 'space manager' do
          let(:manager) { make_manager_for_space(space) }

          before do
            set_current_user(manager)
          end

          it 'returns the dashboard url in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('dashboard_url')).to eq('')
          end

          it 'returns service_plan_guid in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('service_plan_guid')).to eq(service_plan.guid)
          end
        end

        context 'admin' do
          before do
            set_current_user_as_admin
          end

          it 'returns the dashboard url in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('dashboard_url')).to eq('this.should.be.visible.com')
          end

          it 'returns service_plan_guid in the response' do
            get "v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq(200)
            expect(decoded_response.fetch('entity').fetch('service_plan_guid')).to eq(service_plan.guid)
          end
        end
      end

      context 'with a user provided service instance' do
        let(:service_instance) { UserProvidedServiceInstance.make }

        before { set_current_user(developer) }

        it 'returns the service instance with the given guid' do
          get "v2/service_instances/#{service_instance.guid}"
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('metadata').fetch('guid')).to eq(service_instance.guid)
        end

        it 'returns the bindings URL with user_provided_service_instance' do
          get "v2/service_instances/#{service_instance.guid}"
          expect(last_response.status).to eq(200)
          expect(decoded_response.fetch('entity').fetch('service_bindings_url')).to include('user_provided_service_instances')
        end
      end
    end

    describe 'PUT /v2/service_instances/:service_instance_guid' do
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
      let(:space) { service_instance.space }
      let(:developer) { make_developer_for_space(space) }

      before { set_current_user(developer, email: 'user@example.com') }

      context 'when the request is synchronous' do
        before do
          stub_request(:patch, service_broker_url).
            to_return(status: status, body: response_body)
        end

        it 'creates a service audit event for updating the service instance' do
          put "/v2/service_instances/#{service_instance.guid}", body

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
          expect(event.type).to eq('audit.service_instance.update')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata['request']).to include({ 'service_plan_guid' => new_service_plan.guid })
        end

        it 'returns a 201 and updates to the new plan' do
          put "/v2/service_instances/#{service_instance.guid}", body
          expect(last_response).to have_status_code 201
          expect(service_instance.reload.service_plan.guid).to eq(new_service_plan.guid)
        end

        it 'creates an UPDATED service usage event' do
          expect {
            put "/v2/service_instances/#{service_instance.guid}", body
          }.to change { ServiceUsageEvent.count }.by 1

          expect(service_instance.reload.service_plan.guid).to eq(new_service_plan.guid)
          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end

        it 'does not set a Location header' do
          put "/v2/service_instances/#{service_instance.guid}", body
          expect(last_response.headers['Location']).to be_nil
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
            put "/v2/service_instances/#{service_instance.guid}", body
            expect(last_response).to have_status_code(201)
            expect(a_request(:patch, service_broker_url_regex).with(body: hash_including(parameters: parameters))).to have_been_made.times(1)
          end

          context 'and the parameter is not a JSON object' do
            let(:parameters) { 'foo' }

            it 'should reject the request' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response).to have_status_code(400)
              expect(a_request(:put, service_broker_url_regex).
                     with(body: hash_including(parameters: parameters))).
                to have_been_made.times(0)
            end
          end

          context 'when only arbitrary parameters are passed' do
            let(:body) do
              {
                parameters: parameters
              }.to_json
            end

            let(:parameters) do
              { myParam: 'some-value' }
            end

            it 'should pass along the parameters to the service broker' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response).to have_status_code(201)
              expect(a_request(:patch, service_broker_url_regex).with(body: hash_including(parameters: parameters))).to have_been_made.times(1)
            end

            it 'does not create an UPDATED service usage event' do
              expect {
                put "/v2/service_instances/#{service_instance.guid}", body
              }.not_to change { ServiceUsageEvent.count }
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
            put "/v2/service_instances/#{service_instance.guid}", body

            expect(service_instance.reload.name).to eq('new-name')
          end

          it 'updates operation status to succeeded in the database' do
            put "/v2/service_instances/#{service_instance.guid}", body

            expect(service_instance.reload.last_operation.state).to eq('succeeded')
          end

          it 'creates an UPDATED service usage event' do
            expect {
              put "/v2/service_instances/#{service_instance.guid}", body
            }.to change { ServiceUsageEvent.count }.by 1

            expect(service_instance.reload.name).to eq('new-name')
            event = ServiceUsageEvent.last
            expect(event.state).to eq(Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
            expect(event).to match_service_instance(service_instance)
          end

          context 'when the updated service instance name is too long' do
            it 'fails and returns service instance name too long message correctly' do
              new_long_instance_name = 'a' * 51
              put "/v2/service_instances/#{service_instance.guid}",
                MultiJson.dump({ name: new_long_instance_name })

              expect(last_response).to have_status_code(400)
              expect(decoded_response['code']).to eq(60009)
              expect(decoded_response['error_code']).to eq('CF-ServiceInstanceNameTooLong')
            end
          end
        end

        context 'when the request is to update the instance to the plan it already has' do
          let(:body) do
            MultiJson.dump(
              service_plan_guid: old_service_plan.guid
            )
          end

          it 'does not make a request to the broker' do
            put "/v2/service_instances/#{service_instance.guid}", body

            expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
          end

          it 'marks last_operation state as `succeeded`' do
            put "/v2/service_instances/#{service_instance.guid}", body

            expect(service_instance.last_operation.reload.state).to eq 'succeeded'
            expect(service_instance.last_operation.reload.description).to be_nil
          end

          it 'does not create an UPDATED service usage event' do
            expect {
              put "/v2/service_instances/#{service_instance.guid}", body
            }.not_to change { ServiceUsageEvent.count }
          end
        end

        context 'when the service instance tags are updated' do
          let(:body) do
            {
              tags: ['tag1', 'tag2']
            }.to_json
          end

          let(:update_body) do
            {
              tags: max_tags
            }.to_json
          end

          it 'updates the service instance tags in the database' do
            put "/v2/service_instances/#{service_instance.guid}", body

            expect(last_response).to have_status_code(201)
            expect(service_instance.reload.tags).to include('tag1', 'tag2')

            put "/v2/service_instances/#{service_instance.guid}", update_body
            expect(last_response).to have_status_code(201)
            expect(service_instance.reload.tags).to eq(max_tags)
          end

          it 'make sure the tags update works with the max length (edge case)' do
            put "/v2/service_instances/#{service_instance.guid}", update_body
            expect(last_response).to have_status_code(201)
            expect(decoded_response['entity']['tags']).to eq(max_tags)
            expect(service_instance.reload.tags).to eq(max_tags)
          end
        end

        describe 'error cases' do
          context 'when the service instance does not exist' do
            it 'returns a ServiceInstanceNotFound error' do
              put '/v2/service_instances/non-existing-instance-guid', body
              expect(last_response).to have_status_code 404
              expect(decoded_response['error_code']).to eq 'CF-ServiceInstanceNotFound'
            end
          end

          context 'when the tags passed in are too long' do
            it 'returns service instance tags too long message correctly' do
              body = {
                tags: max_tags + ['z'],
              }.to_json

              put "/v2/service_instances/#{service_instance.guid}", body

              expect(last_response.status).to eq(400)
              expect(decoded_response['code']).to eq(60015)
              expect(decoded_response['error_code']).to eq('CF-ServiceInstanceTagsTooLong')
            end
          end

          context 'when the service instance has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
            before do
              service_instance.service_instance_operation = last_operation
              service_instance.save
            end

            it 'should show an error message for update operation' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response).to have_status_code 409
              expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
            end
          end

          context 'when the broker did not declare support for plan upgrades' do
            let(:old_service_plan) { ServicePlan.make(:v2) }

            before { service.update(plan_updateable: false) }

            it 'does not update the service plan in the database' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end

            it 'does not make an api call when the plan does not support upgrades' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
            end

            it 'returns a useful error to the user' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response.body).to match /The service does not support changing plans/
            end
          end

          context 'when the user has read but not write permissions' do
            let(:auditor) { User.make }

            before do
              service_instance.space.organization.add_auditor(auditor)
              set_current_user(auditor)
            end

            it 'does not call out to the service broker' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response).to have_status_code 403
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
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response.status).to eq 400
              expect(last_response.body).to match 'InvalidRelation'
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end
          end

          context 'when the requested plan belongs to a different service' do
            let(:other_broker) { ServiceBroker.make }
            let(:other_service) { Service.make(plan_updateable: true, service_broker: other_broker) }
            let(:other_plan) { ServicePlan.make(service: other_service) }

            let(:body) do
              MultiJson.dump(
                service_plan_guid: other_plan.guid
              )
            end

            it 'rejects the request' do
              put "/v2/service_instances/#{service_instance.guid}", body
              expect(last_response).to have_status_code 400
              expect(decoded_response['error_code']).to match 'InvalidRelation'
              expect(service_instance.reload.service_plan.guid).not_to eq other_plan.guid
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
              put "/v2/service_instances/#{service_instance.guid}", body

              expect(service_instance.last_operation.state).to eq 'failed'
              expect(service_instance.last_operation.type).to eq 'update'
              expect(service_instance.last_operation.description).to eq 'Service broker error: error message'
            end

            it 're-raises the error' do
              put "/v2/service_instances/#{service_instance.guid}", body

              expect(last_response).to have_status_code 502
            end
          end
        end

        describe 'the space_guid parameter' do
          let(:org) { Organization.make }
          let(:space) { Space.make(organization: org) }
          let(:developer) { make_developer_for_space(space) }
          let(:instance) { ManagedServiceInstance.make(space: space) }

          it 'prevents a developer from moving the service instance to a space for which he is also a space developer' do
            space2 = Space.make(organization: org)
            space2.add_developer(developer)

            move_req = MultiJson.dump(
              space_guid: space2.guid,
            )

            put "/v2/service_instances/#{instance.guid}", move_req

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match /Cannot update space for service instance/
          end

          it 'succeeds when the space_guid does not change' do
            req = MultiJson.dump(space_guid: instance.space.guid)
            put "/v2/service_instances/#{instance.guid}", req
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end

          it 'succeeds when the space_guid is not provided' do
            put "/v2/service_instances/#{instance.guid}", {}.to_json
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
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
          expect(event.type).to eq('audit.service_instance.update')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata['request']).to include({ 'service_plan_guid' => new_service_plan.guid })
        end

        it 'returns 201' do
          body = { 'name' => 'blah name' }.to_json
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
          expect(last_response).to have_status_code 201
        end

        context 'when the broker returns a 202' do
          let(:status) { 202 }

          it 'does not update the service plan in the database when the update is in progress' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

            service_instance.reload
            expect(service_instance.last_operation.state).to eq('in progress')
            expect(service_instance.service_plan.guid).not_to eq(new_service_plan.guid)
          end

          it 'does not create an audit event' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
            expect(event).to be_nil
          end

          it 'returns a 202' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
            expect(last_response).to have_status_code 202
          end

          it 'updates the last operation to in progress in the database' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
            expect(service_instance.last_operation.state).to eq('in progress')
          end

          context 'broker returns a operation state' do
            let(:response_body) { { operation: '1e966f2a-28d3-11e6-ab45-685b3585cc4e' }.to_json }
            it 'persists the operation state' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(service_instance.last_operation.broker_provided_operation).to eq('1e966f2a-28d3-11e6-ab45-685b3585cc4e')
            end
          end

          it 'sets the Location header' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
            expect(last_response.headers['Location']).to eq("/v2/service_instances/#{service_instance.guid}")
          end

          it 'immediately enqueues a job to fetch the state' do
            Timecop.freeze do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              job = Delayed::Job.first
              expect(job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch

              poll_interval = VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds).seconds
              expect(job.run_at).to be < Time.now.utc + poll_interval
            end
          end

          context 'when the broker returns 410 for a service instance fetch request' do
            before do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              stub_request(:get, last_operation_state_url(service_instance)).
                to_return(status: 410, body: {}.to_json)
            end

            it 'updates the service instance operation to indicate it has failed' do
              Timecop.freeze(Time.now + 5.minutes) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              service_instance.reload
              expect(service_instance.last_operation.state).to eq('failed')
            end
          end

          context 'when the broker successfully updates the service instance for a service instance fetch request' do
            before do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              stub_request(:get, last_operation_state_url(service_instance)).
                to_return(status: 200, body: {
                state: 'succeeded',
                description: 'Phew, all done'
              }.to_json)
            end

            it 'updates the description of the service instance last operation' do
              Delayed::Job.last.invoke_job

              expect(service_instance.last_operation.reload.state).to eq('succeeded')
              expect(service_instance.last_operation.reload.description).to eq('Phew, all done')
            end

            it 'updates the service plan for the instance' do
              expect(service_instance.reload.service_plan.guid).not_to eq(new_service_plan.guid)
              Delayed::Job.last.invoke_job

              expect(service_instance.reload.service_plan.guid).to eq(new_service_plan.guid)
              expect(a_request(:patch, /#{service_broker_url}/)).to have_been_made.times(1)
            end

            context 'broker responded with an operation field' do
              let(:response_body) { { operation: '1e966f2a-28d3-11e6-ab45-685b3585cc4e' }.to_json }

              it 'invokes last operation with the operation' do
                Delayed::Job.last.invoke_job

                expect(a_request(:get, service_instance_url(service_instance) + '/last_operation').
                  with(query: hash_including({ 'operation' => '1e966f2a-28d3-11e6-ab45-685b3585cc4e' }))).to have_been_made
              end
            end

            it 'creates an UPDATED service usage event' do
              Delayed::Job.last.invoke_job

              expect(service_instance.reload.service_plan.guid).to eq(new_service_plan.guid)
              event = ServiceUsageEvent.last
              expect(event.state).to eq(Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
              expect(event).to match_service_instance(service_instance)
            end

            it 'creates a service audit event for updating the service instance' do
              Timecop.freeze(Time.now + 5.minutes) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              event = VCAP::CloudController::Event.first(type: 'audit.service_instance.update')
              expect(event.type).to eq('audit.service_instance.update')
              expect(event.actor_type).to eq('user')
              expect(event.actor).to eq(developer.guid)
              expect(event.actor_name).to eq('user@example.com')
              expect(event.timestamp).to be
              expect(event.actee).to eq(service_instance.guid)
              expect(event.actee_type).to eq('service_instance')
              expect(event.actee_name).to eq(service_instance.name)
              expect(event.space_guid).to eq(service_instance.space.guid)
              expect(event.organization_guid).to eq(service_instance.space.organization.guid)
              expect(event.metadata['request']).to include({ 'service_plan_guid' => new_service_plan.guid })
            end
          end

          context 'when the request is to update the instance to the plan it already has' do
            let(:body) do
              MultiJson.dump(
                service_plan_guid: old_service_plan.guid
              )
            end

            it 'does not make a request to the broker' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
            end

            it 'marks last_operation state as `succeeded`' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

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
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

            expect(service_instance.reload.name).to eq('new-name')
          end

          it 'updates operation status to succeeded in the database' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

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
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

            expect(a_request(:patch, /#{service_broker_url}/)).not_to have_been_made
          end

          it 'marks last_operation state as `succeeded`' do
            put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

            expect(service_instance.last_operation.reload.state).to eq 'succeeded'
            expect(service_instance.last_operation.reload.description).to be_nil
          end
        end

        describe 'error cases' do
          context 'when the service instance does not exist' do
            it 'returns a ServiceInstanceNotFound error' do
              put '/v2/service_instances/non-existing-instance-guid?accepts_incomplete=true', body
              expect(last_response).to have_status_code 404
              expect(decoded_response['error_code']).to eq 'CF-ServiceInstanceNotFound'
            end
          end

          context 'when the service instance has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
            before do
              service_instance.service_instance_operation = last_operation
              service_instance.save
            end

            it 'should show an error message for update operation' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(last_response).to have_status_code 409
              expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
            end
          end

          describe 'concurrent requests' do
            it 'succeeds for exactly one request' do
              stub_request(:patch, "#{service_broker_url}?accepts_incomplete=true").to_return do |_|
                put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
                expect(last_response).to have_status_code 409
                expect(last_response.body).to match /AsyncServiceInstanceOperationInProgress/

                { status: 202, body: {}.to_json }
              end.times(1).then.to_return do |_|
                { status: 202, body: {}.to_json }
              end

              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(last_response).to have_status_code 202
            end
          end

          context 'when the broker did not declare support for plan upgrades' do
            let(:old_service_plan) { ServicePlan.make(:v2) }

            before { service.update(plan_updateable: false) }

            it 'does not update the service plan in the database' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end

            it 'does not make an api call when the plan does not support upgrades' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
            end

            it 'returns a useful error to the user' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(last_response.body).to match /The service does not support changing plans/
            end
          end

          context 'when the user has read but not write permissions' do
            let(:auditor) { User.make }

            before do
              service_instance.space.organization.add_auditor(auditor)
              set_current_user(auditor)
            end

            it 'does not call out to the service broker' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
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
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body
              expect(last_response).to have_status_code 400
              expect(last_response.body).to match 'InvalidRelation'
              expect(service_instance.reload.service_plan).to eq(old_service_plan)
            end
          end

          context 'when the broker client returns an error as its second return value' do
            let(:response_body) { '{"description": "error message"}' }

            before do
              stub_request(:patch, "#{service_broker_url}?accepts_incomplete=true").
                with(headers: { 'Accept' => 'application/json' }).
                to_return(status: 500, body: response_body, headers: { 'Content-Type' => 'application/json' })
            end

            it 'saves the attributes provided by the first return value' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              expect(service_instance.last_operation.state).to eq 'failed'
              expect(service_instance.last_operation.type).to eq 'update'
              expect(service_instance.last_operation.description).to eq 'Service broker error: error message'
            end

            it 're-raises the error' do
              put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", body

              expect(last_response).to have_status_code 502
            end
          end
        end

        describe 'and the space_guid is provided' do
          let(:org) { Organization.make }
          let(:space) { Space.make(organization: org) }
          let(:developer) { make_developer_for_space(space) }
          let(:instance) { ManagedServiceInstance.make(space: space) }

          it 'prevents a developer from moving the service instance to a space for which he is also a space developer' do
            space2 = Space.make(organization: org)
            space2.add_developer(developer)

            move_req = MultiJson.dump(
              space_guid: space2.guid,
            )

            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", move_req

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match /Cannot update space for service instance/
          end

          it 'succeeds when the space_guid does not change' do
            req = MultiJson.dump(space_guid: instance.space.guid)
            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", req
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end

          it 'succeeds when the space_guid is not provided' do
            put "/v2/service_instances/#{instance.guid}?accepts_incomplete=true", {}.to_json
            expect(last_response).to have_status_code 201
            expect(instance.last_operation.state).to eq 'succeeded'
          end
        end
      end

      context 'when accepts_incomplete is not true or false strings' do
        it 'fails with with InvalidRequest' do
          put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=lol", body

          expect(a_request(:patch, service_broker_url)).to have_been_made.times(0)
          expect(a_request(:delete, service_broker_url)).to have_been_made.times(0)
          expect(last_response).to have_status_code(400)
        end
      end
    end

    describe 'DELETE /v2/service_instances/:service_instance_guid' do
      context 'with a managed service instance' do
        let(:service) { Service.make(:v2) }
        let(:service_plan) { ServicePlan.make(:v2, service: service) }
        let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
        let(:body) { '{}' }
        let(:status) { 200 }
        let(:developer) { make_developer_for_space(space) }
        let(:space) { service_instance.space }

        before do
          stub_deprovision(service_instance, body: body, status: status)
          set_current_user(developer, email: 'user@example.com')
        end

        it 'deletes the service instance with the given guid' do
          expect {
            delete "/v2/service_instances/#{service_instance.guid}"
          }.to change(ServiceInstance, :count).by(-1)
          expect(last_response.status).to eq(204)
          expect(last_response.headers['Location']).to be_nil
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end

        it 'creates a service audit event for deleting the service instance' do
          delete "/v2/service_instances/#{service_instance.guid}"

          expect(last_response).to have_status_code 204

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
          expect(event.type).to eq('audit.service_instance.delete')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata).to have_key('request')
        end

        context 'when the instance has bindings' do
          let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

          before do
            stub_unbind(service_binding)
          end

          it 'does not delete the associated service bindings' do
            expect {
              delete "/v2/service_instances/#{service_instance.guid}"
            }.to change(ServiceBinding, :count).by(0)
            expect(ServiceInstance.find(guid: service_instance.guid)).to be
            expect(ServiceBinding.find(guid: service_binding.guid)).to be
          end

          it 'should give the user an error' do
            delete "/v2/service_instances/#{service_instance.guid}"

            expect(last_response).to have_status_code 400
            expect(last_response.body).to include 'AssociationNotEmpty'
            expect(last_response.body).to include
            'Please delete the service_bindings, service_keys, and routes associations for your service_instances'
          end

          context 'and recursive=true' do
            it 'deletes the associated service bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true"
              }.to change(ServiceBinding, :count).by(-1)
              expect(last_response.status).to eq(204)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
            end
          end
        end

        context 'when the instance has route bindings' do
          let(:route_binding) { RouteBinding.make }
          let(:service_instance) { route_binding.service_instance }
          let(:route) { route_binding.route }

          before do
            stub_unbind(route_binding)
          end

          context 'and the user has not set recursive=true' do
            it 'does not delete the associated service bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}"
              }.to change(RouteBinding, :count).by(0)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be
              expect(RouteBinding.find(guid: route_binding.guid)).to be
            end

            it 'should give the user an error' do
              delete "/v2/service_instances/#{service_instance.guid}"

              expect(last_response).to have_status_code 400
              expect(last_response.body).to include 'AssociationNotEmpty'
              expect(last_response.body).to include
              'Please delete the service_bindings, service_keys, and routes associations for your service_instances'
            end
          end

          context 'and recursive=true' do
            it 'deletes the associated route bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true"
              }.to change(RouteBinding, :count).by(-1)
              expect(last_response.status).to eq(204)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(RouteBinding.find(guid: route_binding.guid)).to be_nil
            end
          end
        end

        context 'when the instance has service keys' do
          let!(:service_key) { ServiceKey.make(service_instance: service_instance) }

          context 'does not provide the recursive parameter' do
            it 'does not delete the associated service keys' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}"
              }.to change(ServiceKey, :count).by(0)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be
              expect(ServiceKey.find(guid: service_key.guid)).to be
            end

            it 'should give the user an error' do
              delete "/v2/service_instances/#{service_instance.guid}"

              expect(last_response).to have_status_code 400
              expect(last_response.body).to include 'AssociationNotEmpty'
              expect(last_response.body).to include
              'Please delete the service_bindings, service_keys, and routes associations for your service_instances'
            end
          end

          context 'the recursive parameter is true' do
            before do
              stub_unbind(service_key)
            end

            it 'deletes the associated service keys' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true"
              }.to change(ServiceKey, :count).by(-1)
              expect(last_response.status).to eq(204)

              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(ServiceKey.find(guid: service_key.guid)).to be_nil
            end

            it 'does not delete the service instance if failed to delete the service key' do
              service_key_1 = ServiceKey.make(service_instance: service_instance)
              stub_unbind(service_key_1, status: 500)

              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true"
              }.to change(ServiceKey, :count).by(-1)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be
              expect(ServiceKey.find(guid: service_key.guid)).to be_nil
              expect(ServiceKey.find(guid: service_key_1.guid)).to be
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
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"
                expect(last_response).to have_status_code 409
                expect(last_response.body).to match /AsyncServiceInstanceOperationInProgress/

                { status: 202, body: {}.to_json }
              end.times(1).then.to_return do |_|
                { status: 202, body: {}.to_json }
              end

              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"
              expect(last_response).to have_status_code 202
            end
          end

          context 'when the broker returns a 202' do
            let(:status) { 202 }
            let(:body) do
              {}.to_json
            end

            it 'should not create a delete event' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(Event.find(type: 'audit.service_instance.delete')).to be_nil
            end

            it 'should create a delete event after the polling finishes' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              broker = service_instance.service_plan.service.service_broker
              broker_uri = URI.parse(broker.broker_url)
              broker_uri.user = broker.auth_username
              broker_uri.password = broker.auth_password
              stub_request(:get, last_operation_state_url(service_instance)).
                to_return(status: 200, body: {
                state: 'succeeded',
                description: 'Done!'
              }.to_json)

              Timecop.freeze Time.now + 2.minute do
                Delayed::Job.last.invoke_job
                expect(Event.find(type: 'audit.service_instance.delete')).to be
              end
            end

            it 'indicates the service instance is being deleted' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code 202
              expect(last_response.headers['Location']).to eq "/v2/service_instances/#{service_instance.guid}"
              expect(service_instance.last_operation.state).to eq 'in progress'

              expect(ManagedServiceInstance.last.last_operation.type).to eq('delete')
              expect(ManagedServiceInstance.last.last_operation.state).to eq('in progress')

              expect(decoded_response['entity']['last_operation']).to be
              expect(decoded_response['entity']['last_operation']['type']).to eq('delete')
              expect(decoded_response['entity']['last_operation']['state']).to eq('in progress')
            end

            context 'when the service broker returns operation state' do
              let(:body) do
                { operation: '8edff4d8-2818-11e6-a53f-685b3585cc4e' }.to_json
              end

              it 'persists the operation state' do
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

                expect(last_response).to have_status_code(202)
                expect(ManagedServiceInstance.last.last_operation.state).to eq('in progress')
                expect(ManagedServiceInstance.last.last_operation.broker_provided_operation).to eq('8edff4d8-2818-11e6-a53f-685b3585cc4e')
              end
            end

            it 'enqueues a polling job to fetch state from the broker' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              stub_request(:get, last_operation_state_url(service_instance)).
                to_return(status: 200, body: {
                last_operation: {
                  state: 'in progress',
                  description: 'Yep, still working'
                }
              }.to_json)

              expect(last_response).to have_status_code 202
              Timecop.freeze Time.now + 30.minutes do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            context 'when the service broker is asked for last operation for delete, with broker operation' do
              let(:body) do
                { operation: '8edff4d8-2818-11e6-a53f-685b3585cc4e' }.to_json
              end

              it 'invokes last operation with the operation' do
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

                stub_request(:get, last_operation_state_url(service_instance)).
                  to_return(status: 200, body: {
                  last_operation: {
                    state: 'in progress'
                  }
                }.to_json)

                Delayed::Job.last.invoke_job

                expect(a_request(:get, service_instance_url(service_instance) + '/last_operation').
                  with(query: hash_including({ 'operation' => '8edff4d8-2818-11e6-a53f-685b3585cc4e' }))).to have_been_made
              end
            end

            context 'when the broker successfully fetches updated information about the instance' do
              before do
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"
                stub_request(:get, last_operation_state_url(service_instance)).
                  to_return(status: 200, body: {
                  state: 'in progress',
                  description: 'still going'
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
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code(204)
              expect(ManagedServiceInstance.find(guid: service_instance_guid)).to be_nil
            end

            it 'logs an audit event' do
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code 204

              event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
              expect(event.type).to eq('audit.service_instance.delete')
              expect(event.actor_type).to eq('user')
              expect(event.actor).to eq(developer.guid)
              expect(event.actor_name).to eq('user@example.com')
              expect(event.timestamp).to be
              expect(event.actee).to eq(service_instance.guid)
              expect(event.actee_type).to eq('service_instance')
              expect(event.actee_name).to eq(service_instance.name)
              expect(event.space_guid).to eq(service_instance.space.guid)
              expect(event.organization_guid).to eq(service_instance.space.organization.guid)
              expect(event.metadata).to have_key('request')
            end

            context 'and with ?async=true' do
              it 'gives accepts_incomplete precedence and deletes the instance synchronously' do
                service_instance_guid = service_instance.guid
                delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true&async=true"

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
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code 502
              expect(decoded_response['description']).to eq("Service instance #{service_instance.name}: Service broker error: #{MultiJson.load(body)['description']}")
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
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code 502
              expect(decoded_response['description']).to eq("Service instance #{service_instance.name}: Service broker error: #{MultiJson.load(body)['description']}")
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
              delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true"

              expect(last_response).to have_status_code 504

              response_description = [
                "Service instance #{service_instance.name}:",
                ' The request to the service broker timed out:',
                " #{service.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}"
              ].join
              expect(decoded_response['description']).to eq(response_description)
            end
          end
        end

        context 'with ?async=true & accepts_incomplete=false' do
          it 'returns a job id' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true"
            expect(last_response).to have_status_code 202
            expect(last_response.headers['Location']).to eq "/v2/jobs/#{decoded_response['entity']['guid']}"
            expect(decoded_response['entity']['guid']).to be
            expect(decoded_response['entity']['status']).to eq 'queued'

            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
          end

          it 'creates a service audit event for deleting the service instance' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true"
            expect(last_response).to have_status_code 202

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
            expect(event).to be_nil

            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.delete')
            expect(event.type).to eq('audit.service_instance.delete')
            expect(event.actor_type).to eq('user')
            expect(event.actor).to eq(developer.guid)
            expect(event.actor_name).to eq('user@example.com')
            expect(event.timestamp).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.actee_type).to eq('service_instance')
            expect(event.actee_name).to eq(service_instance.name)
            expect(event.space_guid).to eq(service_instance.space.guid)
            expect(event.organization_guid).to eq(service_instance.space.organization.guid)
            expect(event.metadata).to have_key('request')
          end

          it 'does not get stuck in progress if the service instance is delete synchronously before the job runs' do
            delete "/v2/service_instances/#{service_instance.guid}?async=true"
            expect(last_response).to have_status_code 202

            job_url = decoded_response['metadata']['url']

            delete "/v2/service_instances/#{service_instance.guid}"
            expect(last_response).to have_status_code 204

            Delayed::Worker.new.work_off

            get job_url
            expect(decoded_response['entity']['status']).to eq 'finished'
          end

          context 'when a synchronous request is made before the enqueued job can run' do
            it 'succeeds the synchronous request and assumes the job will properly handle the missing resource when it eventually runs' do
              delete "/v2/service_instances/#{service_instance.guid}?async=true"
              expect(last_response).to have_status_code 202
              expect(service_instance.exists?).to be_truthy

              delete "/v2/service_instances/#{service_instance.guid}"
              expect(last_response).to have_status_code 204
              expect(service_instance.exists?).to be_falsey

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
            end
          end

          context 'when the service broker returns 500' do
            let(:status) { 500 }

            it 'enqueues the standard ModelDeletion job which marks the state as failed' do
              service_instance_guid = service_instance.guid
              delete "/v2/service_instances/#{service_instance.guid}?async=true"

              expect(last_response).to have_status_code 202
              expect(decoded_response['entity']['status']).to eq 'queued'

              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              service_instance = ServiceInstance.find(guid: service_instance_guid)
              expect(service_instance).to_not be_nil
              expect(service_instance.last_operation.type).to eq 'delete'
              expect(service_instance.last_operation.state).to eq 'failed'
            end
          end
        end

        context 'and the service broker returns a 409' do
          let(:body) { '{"description": "service broker error"}' }
          let(:status) { 409 }

          it 'it returns a CF-ServiceBrokerBadResponse error' do
            delete "/v2/service_instances/#{service_instance.guid}"

            expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerBadResponse'
            expect(JSON.parse(last_response.body)['description']).to include 'service broker error'
          end
        end

        context 'and the instance cannot be found' do
          it 'returns a 404' do
            delete '/v2/service_instances/non-existing-instance'
            expect(last_response.status).to eq 404
          end
        end

        context 'and the instance operation is in progress' do
          let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
          before do
            service_instance.service_instance_operation = last_operation
          end

          it 'should show an error message for delete operation' do
            delete "/v2/service_instances/#{service_instance.guid}"
            expect(last_response.status).to eq 409
            expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
          end
        end

        context 'with ?purge=true' do
          before { set_current_user_as_admin }

          it 'deletes the service instance without request to broker' do
            expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil

            delete "/v2/service_instances/#{service_instance.guid}?purge=true"

            expect(last_response.status).to eq(204)
            expect(ManagedServiceInstance.find(guid: service_instance.guid)).to be_nil
          end

          context 'when the user is not an admin' do
            it 'raises an authentication error and does not delete the instance' do
              set_current_user(developer)

              expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil

              delete "/v2/service_instances/#{service_instance.guid}?purge=true"

              expect(last_response.status).to eq(403)
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil
            end
          end

          context 'when the service instance has service bindings' do
            let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
            let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }

            it 'deletes the service instance and all of its service bindings' do
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil

              delete "/v2/service_instances/#{service_instance.guid}?purge=true"

              expect(ServiceBinding.find(guid: service_binding_1.guid)).to be_nil
              expect(ServiceBinding.find(guid: service_binding_2.guid)).to be_nil
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(last_response.status).to eq(204)
            end
          end

          context 'when the service instance as service keys' do
            let!(:service_key_1) { ServiceKey.make(service_instance: service_instance) }
            let!(:service_key_2) { ServiceKey.make(service_instance: service_instance) }

            it 'deletes the service instance and all of its service keys' do
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil

              delete "/v2/service_instances/#{service_instance.guid}?purge=true"

              expect(ServiceKey.find(guid: service_key_1.guid)).to be_nil
              expect(ServiceKey.find(guid: service_key_2.guid)).to be_nil
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(last_response.status).to eq(204)
            end
          end

          context 'when the service instance has an operation in progress' do
            before do
              service_instance.save_with_new_operation({}, { type: 'type', state: 'in progress' })
            end

            it 'deletes the service instance without request to broker' do
              expect(service_instance.last_operation.state).to eq('in progress')
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).not_to be_nil

              delete "/v2/service_instances/#{service_instance.guid}?purge=true"

              expect(last_response.status).to eq(204)
              expect(ManagedServiceInstance.find(guid: service_instance.guid)).to be_nil
            end
          end
        end
      end

      context 'with a user provided service instance' do
        let!(:service_instance) { UserProvidedServiceInstance.make }
        let(:developer) { make_developer_for_space(service_instance.space) }

        before { set_current_user(developer, email: 'user@example.com') }

        it 'creates a user_provided_service_instance audit event for deleting the service instance' do
          delete "/v2/service_instances/#{service_instance.guid}"

          event = VCAP::CloudController::Event.first(type: 'audit.user_provided_service_instance.delete')
          expect(event.type).to eq('audit.user_provided_service_instance.delete')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('user_provided_service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata).to have_key('request')
        end

        it 'deletes the service instance with the given guid' do
          delete "/v2/service_instances/#{service_instance.guid}"
          expect(last_response).to have_status_code 204
          expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
        end

        context 'when the instance has bindings' do
          let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

          it 'does not delete the associated service bindings' do
            expect {
              delete "/v2/service_instances/#{service_instance.guid}"
            }.to change(ServiceBinding, :count).by(0)
            expect(ServiceInstance.find(guid: service_instance.guid)).to be
            expect(ServiceBinding.find(guid: service_binding.guid)).to be
          end

          it 'should give the user an error' do
            delete "/v2/service_instances/#{service_instance.guid}"

            expect(last_response).to have_status_code 400
            expect(last_response.body).to include 'AssociationNotEmpty'
            expect(last_response.body).to include
            'Please delete the service_bindings, service_keys, and routes associations for your service_instances'
          end

          context 'when recursive=true' do
            it 'deletes the associated service bindings' do
              expect {
                delete "/v2/service_instances/#{service_instance.guid}?recursive=true"
              }.to change(ServiceBinding, :count).by(-1)
              expect(last_response.status).to eq(204)
              expect(ServiceInstance.find(guid: service_instance.guid)).to be_nil
              expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
            end
          end
        end
      end
    end

    describe 'GET /v2/service_instances/:service_instance_guid/routes' do
      let(:space)   { Space.make }
      let(:manager) { make_manager_for_space(space) }
      let(:auditor) { make_auditor_for_space(space) }
      let(:developer) { make_developer_for_space(space) }

      context 'when the user is not a member of the space this instance exists in' do
        let(:space_a)   { Space.make }
        let(:instance)  { ManagedServiceInstance.make(space: space_a) }

        def verify_forbidden(user)
          set_current_user(user)
          get "/v2/service_instances/#{instance.guid}/routes"
          expect(last_response.status).to eql(403)
        end

        it 'returns the forbidden code for developers' do
          verify_forbidden developer
        end

        it 'returns the forbidden code for managers' do
          verify_forbidden manager
        end

        it 'returns the forbidden code for auditors' do
          verify_forbidden auditor
        end
      end

      context 'when the user is a member of the space this instance exists in' do
        let(:instance_a)  { ManagedServiceInstance.make(:routing, space: space) }
        let(:instance_b)  { ManagedServiceInstance.make(:routing, space: space) }
        let(:route_a) { Route.make(space: space) }
        let(:route_b) { Route.make(space: space) }
        let(:route_c) { Route.make(space: space) }
        let!(:route_binding_a) { RouteBinding.make(route: route_a, service_instance: instance_a) }
        let!(:route_binding_b) { RouteBinding.make(route: route_b, service_instance: instance_a) }
        let!(:route_binding_c) { RouteBinding.make(route: route_c, service_instance: instance_b) }

        context 'when the user is a SpaceAuditor' do
          it 'returns the routes that belong to the service instance' do
            set_current_user auditor
            get "/v2/service_instances/#{instance_a.guid}/routes"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(2)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_a.guid)
            expect(decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')).to eq(route_b.guid)

            get "/v2/service_instances/#{instance_b.guid}/routes"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(1)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_c.guid)
          end

          context 'when the user is a SpaceManager' do
            it 'returns the routes that belong to the service instance' do
              set_current_user manager
              get "/v2/service_instances/#{instance_a.guid}/routes"
              expect(last_response.status).to eql(200)
              expect(decoded_response.fetch('total_results')).to eq(2)
              expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_a.guid)
              expect(decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')).to eq(route_b.guid)

              get "/v2/service_instances/#{instance_b.guid}/routes"
              expect(last_response.status).to eql(200)
              expect(decoded_response.fetch('total_results')).to eq(1)
              expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_c.guid)
            end
          end
        end

        context 'when the user is a SpaceDeveloper' do
          it 'returns the routes that belong to the service instance' do
            set_current_user developer
            get "/v2/service_instances/#{instance_a.guid}/routes"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(2)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_a.guid)
            expect(decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')).to eq(route_b.guid)

            get "/v2/service_instances/#{instance_b.guid}/routes"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(1)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(route_c.guid)
          end
        end
      end
    end

    describe 'PUT /v2/service_instances/:service_instance_guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:service_instance) { ManagedServiceInstance.make(:routing, space: space) }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:opts) { {} }
      let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

      before do
        stub_bind(service_instance, opts)
        TestConfig.config['route_services_enabled'] = true
        set_current_user(developer)
      end

      it 'associates the route and the service instance' do
        set_current_user(developer, email: 'developer@example.com')
        get "/v2/service_instances/#{service_instance.guid}/routes"
        expect(last_response).to have_status_code(200)
        expect(JSON.parse(last_response.body)['total_results']).to eql(0)

        put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        expect(last_response).to have_status_code(201)

        event = VCAP::CloudController::Event.first(type: 'audit.service_instance.bind_route')
        expect(event).not_to be_nil
        expect(event.type).to eq('audit.service_instance.bind_route')
        expect(event.actor_type).to eq('user')
        expect(event.actor).to eq(developer.guid)
        expect(event.actor_name).to eq('developer@example.com')
        expect(event.timestamp).to be
        expect(event.actee).to eq(service_instance.guid)
        expect(event.actee_type).to eq('service_instance')
        expect(event.actee_name).to eq(service_instance.name)
        expect(event.space_guid).to eq(service_instance.space.guid)
        expect(event.organization_guid).to eq(service_instance.space.organization.guid)
        expect(event.metadata['request']).to include({ 'route_guid' => route.guid })

        get "/v2/service_instances/#{service_instance.guid}/routes"
        expect(last_response).to have_status_code(200)
        expect(JSON.parse(last_response.body)['total_results']).to eql(1)
      end

      it 'sends a bind request to the service broker' do
        put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        expect(last_response.status).to eq(201)

        binding             = RouteBinding.last
        service_plan        = binding.service_plan
        service             = binding.service
        service_binding_uri = service_binding_url(binding)
        expected_body       = { service_id: service.broker_provided_id, plan_id: service_plan.broker_provided_id, bind_resource: { route: route.uri } }
        expect(a_request(:put, service_binding_uri).with(body: expected_body)).to have_been_made
      end

      context 'when the body is empty string' do
        before do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        end

        it 'should ignore the body and do not raise error' do
          expect(last_response).to have_status_code(201)
        end
      end

      context 'when the client provides arbitrary parameters' do
        before do
          body = MultiJson.dump(parameters: parameters)
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}", body
        end

        context 'and the parameter is a JSON object' do
          let(:parameters) do
            { foo: 'bar', bar: 'baz' }
          end

          it 'should pass along the parameters to the service broker' do
            binding             = RouteBinding.last
            service_binding_uri = service_binding_url(binding)

            expect(last_response).to have_status_code(201)
            expect(a_request(:put, service_binding_uri).
                       with(body: hash_including(parameters: parameters))).
              to have_been_made.times(1)
          end
        end

        context 'and the parameter is not a JSON object' do
          let(:parameters) { 'foo' }

          it 'should reject the request' do
            expect(last_response).to have_status_code(400)
            expect(last_response.body).to include('Expected instance of Hash, given an instance of String')
            expect(a_request(:put, service_broker_url_regex).
                       with(body: hash_including(parameters: parameters))).
              to have_been_made.times(0)
          end
        end
      end

      context 'binding permissions' do
        context 'admin' do
          it 'allows an admin to bind a space' do
            set_current_user_as_admin
            put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
            expect(last_response.status).to eq(201)
          end
        end

        context 'neither an admin nor a Space Developer' do
          let(:manager) { make_manager_for_space(space) }
          it 'raises an error' do
            set_current_user(manager)
            put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
            expect(last_response.status).to eq(403)
            expect(last_response.body).to include('You are not authorized to perform the requested action')
          end
        end
      end

      context 'when the service instance is not a route service' do
        let(:service_instance) { ManagedServiceInstance.make(space: space) }

        it 'raises a 400 error' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to include('does not support route binding')
        end
      end

      context 'when route service is disabled' do
        before do
          TestConfig.config[:route_services_enabled] = false
        end

        it 'should raise a 403 error' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

          expect(last_response).to have_status_code(403)
          expect(decoded_response['description']).to eq 'Support for route services is disabled'
        end
      end

      context 'when the route does not exist' do
        it 'raises an error' do
          put "/v2/service_instances/#{service_instance.guid}/routes/random-guid"
          expect(last_response.status).to eq(404)
          expect(JSON.parse(last_response.body)['description']).
            to include('route could not be found')
        end
      end

      context 'when the route has an associated service instance' do
        before do
          RouteBinding.make service_instance: service_instance, route: route
        end

        it 'raises RouteAlreadyBoundToServiceInstance' do
          new_service_instance = ManagedServiceInstance.make(:routing, space: space)
          get "/v2/service_instances/#{new_service_instance.guid}/routes"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)

          put "/v2/service_instances/#{new_service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to eq('A route may only be bound to a single service instance')

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.bind_route')
          expect(event).to be_nil

          get "/v2/service_instances/#{new_service_instance.guid}/routes"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)
        end

        context 'and the associated is the same as the requested instance' do
          it 'raises ServiceInstanceAlreadyBoundToSameRoute' do
            get "/v2/service_instances/#{service_instance.guid}/routes"
            expect(last_response).to have_status_code(200)
            expect(JSON.parse(last_response.body)['total_results']).to eql(1)

            put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
            expect(last_response).to have_status_code(400)
            expect(JSON.parse(last_response.body)['description']).
              to eq('The route and service instance are already bound.')

            event = VCAP::CloudController::Event.first(type: 'audit.service_instance.bind_route')
            expect(event).to be_nil

            get "/v2/service_instances/#{service_instance.guid}/routes"
            expect(last_response).to have_status_code(200)
            expect(JSON.parse(last_response.body)['total_results']).to eql(1)
          end
        end
      end

      context 'when the route is mapped to a diego app' do
        before do
          diego_process = ProcessModelFactory.make(diego: true, space: route.space, state: 'STARTED')
          RouteMappingModel.make(app: diego_process.app, route: route, process_type: diego_process.type)
        end

        it 'successfully binds to the route' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response).to have_status_code(201)
        end

        context 'and is mapped to another diego app as well' do
          before do
            another_diego_process = ProcessModelFactory.make(diego: true, space: route.space, state: 'STARTED')
            RouteMappingModel.make(app: another_diego_process.app, route: route, process_type: another_diego_process.type)
          end

          it 'raises RouteServiceRequiresDiego' do
            put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

            expect(last_response).to have_status_code(201)
          end
        end
      end

      context 'when the route is mapped to a non-diego app' do
        before do
          process = ProcessModelFactory.make(diego: false, space: route.space, state: 'STARTED')
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
        end

        it 'raises RouteServiceRequiresDiego' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to eq('Route services are only supported for apps on Diego. Unbind the service instance from the route or enable Diego for the app.')
        end

        context 'and is mapped to a diego app' do
          before do
            diego_process = ProcessModelFactory.make(diego: true, space: route.space, state: 'STARTED')
            RouteMappingModel.make(app: diego_process.app, route: route, process_type: diego_process.type)
          end

          it 'raises RouteServiceRequiresDiego' do
            put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

            expect(last_response.status).to eq(400)

            expect(JSON.parse(last_response.body)['description']).
              to eq('Route services are only supported for apps on Diego. Unbind the service instance from the route or enable Diego for the app.')
          end
        end
      end

      context 'when attempting to bind to an unbindable service' do
        before do
          service_instance.service.bindable = false
          service_instance.service.save

          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        end

        it 'raises UnbindableService error' do
          hash_body = JSON.parse(last_response.body)
          expect(hash_body['error_code']).to eq('CF-UnbindableService')
          expect(last_response).to have_status_code(400)
        end
      end

      context 'when attempting to bind to an unbindable service plan' do
        before do
          service_instance.service_plan.bindable = false
          service_instance.service_plan.save

          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        end

        it 'raises UnbindableService error' do
          hash_body = JSON.parse(last_response.body)
          expect(hash_body['error_code']).to eq('CF-UnbindableService')
          expect(last_response).to have_status_code(400)
        end
      end

      context 'when the instance operation is in progress' do
        before do
          service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
        end

        it 'does not send a bind request to broker' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

          expect(a_request(:put, bind_url(service_instance))).to_not have_been_made
        end

        it 'does not trigger orphan mitigation' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

          orphan_mitigation_job = Delayed::Job.first
          expect(orphan_mitigation_job).to be_nil

          expect(a_request(:delete, service_binding_url_pattern)).not_to have_been_made
        end

        it 'should show an error message for create bind operation' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response).to have_status_code 409
          expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
        end
      end

      context 'when the route and service_instance are not in the same space' do
        let(:other_space) { Space.make(organization: space.organization) }
        let(:service_instance) { ManagedServiceInstance.make(:routing, space: other_space) }

        before do
          other_space.add_developer(developer)
          other_space.save
        end

        it 'raises an error' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to include('The service instance and the route are in different spaces.')
        end

        it 'does NOT send a bind request to the service broker' do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

          expect(a_request(:put, service_binding_url_pattern)).not_to have_been_made
        end
      end

      describe 'binding errors' do
        subject(:make_request) do
          put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
        end

        let(:opts) do
          {
            status: bind_status,
            body:   bind_body.to_json
          }
        end

        context 'when the v2 broker returns a 409' do
          let(:bind_status) { 409 }
          let(:bind_body) { {} }

          it 'returns a 409' do
            make_request
            expect(last_response).to have_status_code 409
          end

          it 'returns a ServiceBrokerConflict error' do
            make_request
            expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerConflict'
          end
        end

        context 'when the v2 broker returns any other error' do
          let(:bind_status) { 500 }
          let(:bind_body) { { description: 'ERROR MESSAGE HERE' } }

          it 'passes through the error message' do
            make_request
            expect(last_response).to have_status_code 502
            expect(decoded_response['description']).to match /ERROR MESSAGE HERE/
            expect(service_instance.refresh.last_operation).to be_nil
          end

          context 'when the instance has a last_operation' do
            before do
              service_instance.service_instance_operation = ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
            end

            it 'rolls back the last_operation of the service instance' do
              make_request
              expect(service_instance.refresh.last_operation.state).to eq 'succeeded'
              expect(service_instance.refresh.last_operation.type).to eq 'create'
            end
          end
        end

        context 'when the broker returns a syslog_drain_url and the service does not require one' do
          let(:bind_status) { 200 }
          let(:bind_body) { { 'syslog_drain_url' => 'http://syslog.com/drain' } }

          it 'returns ServiceBrokerInvalidSyslogDrainUrl error to the user' do
            make_request
            expect(last_response).to have_status_code 502
            expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerInvalidSyslogDrainUrl'
          end

          it 'triggers orphan mitigation' do
            make_request
            expect(last_response).to have_status_code 502

            orphan_mitigation_job = Delayed::Job.first
            expect(orphan_mitigation_job).not_to be_nil
            expect(orphan_mitigation_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding
          end
        end
      end
    end

    describe 'DELETE /v2/service_instances/:service_instance_guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:service_instance) { ManagedServiceInstance.make(:routing, space: space) }
      let(:route) { Route.make(space: space) }

      before { set_current_user developer }

      context 'when a service has an associated route' do
        let!(:route_binding) { RouteBinding.make(route: route, service_instance: service_instance) }

        before do
          stub_unbind(route_binding)
        end

        it 'deletes the association between the route and the service instance' do
          set_current_user(developer, email: 'developer@example.com')
          get "/v2/service_instances/#{service_instance.guid}/routes"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(1)

          delete "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(204)
          expect(last_response.body).to be_empty

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.unbind_route')
          expect(event).not_to be_nil
          expect(event.type).to eq('audit.service_instance.unbind_route')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq('developer@example.com')
          expect(event.timestamp).to be
          expect(event.actee).to eq(service_instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(service_instance.name)
          expect(event.space_guid).to eq(service_instance.space.guid)
          expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          expect(event.metadata['request']).to include({ 'route_guid' => route.guid })

          get "/v2/service_instances/#{service_instance.guid}/routes"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)
        end

        it 'sends an unbind request to the broker' do
          delete "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(204)
          expect(last_response.body).to be_empty

          service_plan        = route_binding.service_plan
          service             = route_binding.service
          query               = "plan_id=#{service_plan.broker_provided_id}&service_id=#{service.broker_provided_id}"
          service_binding_uri = service_binding_url(route_binding, query)
          expect(a_request(:delete, service_binding_uri)).to have_been_made
        end
      end

      context 'when the service_instance does not exist' do
        it 'returns a 404' do
          delete "/v2/service_instances/fake-guid/routes/#{route.guid}"
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the route does not exist' do
        it 'returns a 404' do
          delete "/v2/service_instances/#{service_instance.guid}/routes/fake-guid"
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the route and service are not bound' do
        it 'returns a 400 InvalidRelation error' do
          delete "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).to include('is not bound to service instance')
        end
      end
    end

    describe 'GET /v2/service_instances/:service_instance_guid/permissions' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:instance) { ManagedServiceInstance.make(space: space) }
      let(:user) { User.make }

      context 'when the user is a member of the space this instance exists in' do
        describe 'permissions' do
          {
            'space_auditor'       => { manage: false, read: true },
            'space_developer'     => { manage: true, read: true },
            'space_manager'       => { manage: false, read: true },
            'org_auditor'         => { manage: false, read: false },
            'org_billing_manager' => { manage: false, read: false },
            'org_manager'         => { manage: false, read: true },
            'admin'               => { manage: true, read: true },
            'admin_read_only'     => { manage: false, read: true },
            'global_auditor'      => { manage: false, read: false },
          }.each do |role, expected_return_values|
            context "as an #{role}" do
              before do
                set_current_user_as_role(
                  role:   role,
                  org:    org,
                  space:  space,
                  user:   user,
                  scopes: ['cloud_controller.read']
                )
              end

              it "returns #{expected_return_values}" do
                get "/v2/service_instances/#{instance.guid}/permissions"
                expect(last_response.status).to eq(200), "Expected 200, got: #{last_response.status}, role: #{role}"
                manage_response = JSON.parse(last_response.body)['manage']
                read_response   = JSON.parse(last_response.body)['read']
                expect(manage_response).to eq(expected_return_values[:manage]), "Expected #{expected_return_values[:manage]}, got: #{read_response}, role: #{role}"
                expect(read_response).to eq(expected_return_values[:read]), "Expected #{expected_return_values[:read]}, got: #{read_response}, role: #{role}"
              end
            end
          end
        end

        describe 'scopes' do
          let(:developer) { make_developer_for_space(space) }

          context 'when the user has only the cloud_controller.read scope' do
            it 'returns a JSON payload indicating they have permission to manage this instance' do
              set_current_user(developer, { scopes: ['cloud_controller.read'] })
              get "/v2/service_instances/#{instance.guid}/permissions"
              expect(last_response.status).to eql(200)
              expect(JSON.parse(last_response.body)['manage']).to be true
              expect(JSON.parse(last_response.body)['read']).to be true
            end
          end

          context 'when the user has only the cloud_controller_service_permissions.read scope' do
            it 'returns a JSON payload indicating they have permission to manage this instance' do
              set_current_user(developer, { scopes: ['cloud_controller_service_permissions.read'] })
              get "/v2/service_instances/#{instance.guid}/permissions"
              expect(last_response.status).to eql(200)
              expect(JSON.parse(last_response.body)['manage']).to be true
              expect(JSON.parse(last_response.body)['read']).to be true
            end
          end

          context 'when the user does not have either necessary scope' do
            it 'returns InsufficientScope' do
              set_current_user(developer, { scopes: ['cloud_controller.write'] })
              get "/v2/service_instances/#{instance.guid}/permissions"
              expect(last_response.status).to eql(403)
              expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
            end
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:instance) { ManagedServiceInstance.make }

        it 'returns a JSON payload indicating the user does not have permission to manage this instance' do
          set_current_user(user)
          get "/v2/service_instances/#{instance.guid}/permissions"
          expect(last_response.status).to eql(200)
          expect(JSON.parse(last_response.body)['manage']).to be false
          expect(JSON.parse(last_response.body)['read']).to be false
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:developer) { nil }

        it 'returns an error saying that the user is not authenticated' do
          set_current_user(developer)
          get '/v2/service_instances/any-guid/permissions'
          expect(last_response.status).to eq(401)
          expect(last_response.body).to include('NotAuthenticated')
        end
      end

      context 'when the service instance does not exist' do
        it 'returns an error saying the instance was not found' do
          set_current_user(user)
          get '/v2/service_instances/nonexistent_instance/permissions'
          expect(last_response.status).to eql 404
          expect(last_response.body).to include('ServiceInstanceNotFound')
        end
      end
    end

    describe 'GET /v2/service_instances/:service_instance_guid/service_keys' do
      let(:space)   { Space.make }
      let(:manager) { make_manager_for_space(space) }
      let(:auditor) { make_auditor_for_space(space) }
      let(:developer) { make_developer_for_space(space) }

      context 'when the user is not a member of the space this instance exists in' do
        let(:space_a)   { Space.make }
        let(:instance)  { ManagedServiceInstance.make(space: space_a) }

        def verify_forbidden(user)
          set_current_user(user)
          get "/v2/service_instances/#{instance.guid}/service_keys"
          expect(last_response.status).to eql(403)
        end

        it 'returns the forbidden code for developers' do
          verify_forbidden developer
        end

        it 'returns the forbidden code for managers' do
          verify_forbidden manager
        end

        it 'returns the forbidden code for auditors' do
          verify_forbidden auditor
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

        context 'when the user is not of developer role' do
          it 'return an empty service key list if the user is of space manager role' do
            set_current_user(manager)
            get "/v2/service_instances/#{instance_a.guid}/service_keys"
            expect(last_response.status).to eql(403)
            expect(MultiJson.load(last_response.body)['description']).to eq('You are not authorized to perform the requested action')
          end

          it 'return an empty service key list if the user is of space auditor role' do
            set_current_user(auditor)
            get "/v2/service_instances/#{instance_a.guid}/service_keys"
            expect(last_response.status).to eql(403)
            expect(MultiJson.load(last_response.body)['description']).to eq('You are not authorized to perform the requested action')
          end
        end

        context 'when the user is of developer role' do
          before { set_current_user(developer) }

          it 'returns the service keys that belong to the service instance' do
            get "/v2/service_instances/#{instance_a.guid}/service_keys"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(2)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_a.guid)
            expect(decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')).to eq(service_key_b.guid)

            get "/v2/service_instances/#{instance_b.guid}/service_keys"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(1)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_c.guid)
          end

          it 'returns the service keys filtered by key name' do
            get "/v2/service_instances/#{instance_a.guid}/service_keys?q=name:fake-key-a"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(1)
            expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eq(service_key_a.guid)

            get "/v2/service_instances/#{instance_b.guid}/service_keys?q=name:non-exist-key-name"
            expect(last_response.status).to eql(200)
            expect(decoded_response.fetch('total_results')).to eq(0)
          end
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
      let(:developer) { make_developer_for_space(space) }

      before { set_current_user(developer) }

      it 'returns duplicate name message correctly' do
        existing_service_instance = ManagedServiceInstance.make(space: space)
        service_instance_params = {
          name: existing_service_instance.name,
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

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
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

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
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

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
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

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
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60007)
      end

      it 'returns service plan name too long message correctly' do
        service_instance_params = {
          name: 'n' * 51,
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60009)
        expect(decoded_response['error_code']).to eq('CF-ServiceInstanceNameTooLong')
      end

      it 'returns service instance tags too long message correctly' do
        service_instance_params = {
          name: 'sweet name',
          tags: ['a' * 2049],
          space_guid: space.guid,
          service_plan_guid: free_plan.guid
        }
        post '/v2/service_instances', MultiJson.dump(service_instance_params)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(60015)
        expect(decoded_response['error_code']).to eq('CF-ServiceInstanceTagsTooLong')
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

          set_current_user(make_developer_for_space(space))

          post '/v2/service_instances', MultiJson.dump(body)
          expect(last_response).to have_status_code 400
          expect(decoded_response['description']).to match(/invalid.*space.*/)
        end
      end

      it 'returns service does not support routes message correctly' do
        route = Route.make
        service_instance = ManagedServiceInstance.make

        set_current_user_as_admin
        put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}"

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to include('This service does not support route binding')
        expect(decoded_response['code']).to eq(130006)
      end
    end

    describe '.translate_validation_exception' do
      let(:e) { instance_double(Sequel::ValidationFailed) }
      let(:errors) { instance_double(Sequel::Model::Errors) }
      let(:attributes) { {} }

      let(:space_and_name_errors) { nil }
      let(:quota_errors) { nil }
      let(:service_plan_errors) { nil }
      let(:service_instance_name_errors) { nil }
      let(:service_instance_tags_errors) { nil }
      let(:service_instance_errors) { nil }
      let(:full_messages) { 'Service instance invalid message' }

      before do
        allow(e).to receive(:errors).and_return(errors)
        allow(errors).to receive(:on).with([:space_id, :name]).and_return(space_and_name_errors)
        allow(errors).to receive(:on).with(:quota).and_return(quota_errors)
        allow(errors).to receive(:on).with(:service_plan).and_return(service_plan_errors)
        allow(errors).to receive(:on).with(:name).and_return(service_instance_name_errors)
        allow(errors).to receive(:on).with(:tags).and_return(service_instance_tags_errors)
        allow(errors).to receive(:on).with(:service_instance).and_return(service_instance_errors)
        allow(errors).to receive(:full_messages).and_return(full_messages)
      end

      it 'returns a generic ServiceInstanceInvalid error' do
        expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceInvalid')
        expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).message).to include(full_messages)
      end

      context "when errors are included but aren't supported validation exceptions" do
        let(:space_and_name_errors) { [:stuff] }
        let(:quota_errors) { [:stuff] }
        let(:service_plan_errors) { [:stuff] }
        let(:service_instance_name_errors) { [:stuff] }
        let(:service_instance_tags_errors) { [:stuff] }

        it 'returns a generic ServiceInstanceInvalid error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceInvalid')
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).message).to include(full_messages)
        end
      end

      context 'when there is a service instance name taken error' do
        let(:attributes) { { 'name' => 'test name' } }
        let(:space_and_name_errors) { [:unique] }

        it 'returns a ServiceInstanceNameTaken error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceNameTaken')
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).message).to include(attributes['name'])
        end
      end

      context 'when the space quota has been exceeded' do
        let(:quota_errors) { [:service_instance_space_quota_exceeded] }

        it 'returns a ServiceInstanceSpaceQuotaExceeded error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceSpaceQuotaExceeded')
        end
      end

      context 'when the service instance quota has been exceeded' do
        let(:quota_errors) { [:service_instance_quota_exceeded] }

        it 'returns a ServiceInstanceSpaceQuotaExceeded error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceQuotaExceeded')
        end
      end

      context 'when the service plan is not allowed by the space quota' do
        let(:service_plan_errors) { [:paid_services_not_allowed_by_space_quota] }

        it 'returns a ServiceInstanceServicePlanNotAllowedBySpaceQuota error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
        end
      end

      context 'when the service plan is not allowed by the service instance quota' do
        let(:service_plan_errors) { [:paid_services_not_allowed_by_quota] }

        it 'returns a ServiceInstanceServicePlanNotAllowed error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceServicePlanNotAllowed')
        end
      end

      context 'when the service instance name is too long' do
        let(:service_instance_name_errors) { [:max_length] }

        it 'returns a ServiceInstanceNameTooLong error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceNameTooLong')
        end
      end

      context 'when the service instance name is empty' do
        let(:service_instance_name_errors) { [:presence] }

        it 'returns a ServiceInstanceNameEmpty error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceNameEmpty')
        end
      end

      context 'when the service instance tags are too long' do
        let(:service_instance_tags_errors) { [:too_long] }

        it 'returns a ServiceInstanceTagsTooLong error' do
          expect(VCAP::CloudController::ServiceInstancesController.translate_validation_exception(e, attributes).name).to eq('ServiceInstanceTagsTooLong')
        end
      end
    end

    def create_managed_service_instance(user_opts={})
      arbitrary_params = user_opts.delete(:parameters)
      accepts_incomplete = user_opts.delete(:accepts_incomplete) { |_| 'true' }
      tags = user_opts.delete(:tags)

      body = {
        name: 'foo',
        space_guid: space.guid,
        service_plan_guid: plan.guid,
      }
      body[:parameters] = arbitrary_params if arbitrary_params
      body[:tags] = tags if tags
      req = MultiJson.dump(body)

      if accepts_incomplete
        post "/v2/service_instances?accepts_incomplete=#{accepts_incomplete}", req
      else
        post '/v2/service_instances', req
      end
      ServiceInstance.last
    end

    def create_user_provided_service_instance
      req = MultiJson.dump(
        name: 'foo',
        space_guid: space.guid
      )

      post '/v2/user_provided_service_instances', req

      ServiceInstance.last
    end

    def max_tags
      ['a' * 1024, 'b' * 1024] # 2048 characters
    end
  end
end
