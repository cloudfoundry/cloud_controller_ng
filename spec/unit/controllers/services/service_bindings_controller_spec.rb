require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingsController do
    describe 'Query Parameters' do
      it { expect(ServiceBindingsController).to be_queryable_by(:app_guid) }
      it { expect(ServiceBindingsController).to be_queryable_by(:service_instance_guid) }
    end

    describe 'Attributes' do
      it do
        expect(ServiceBindingsController).to have_creatable_attributes({
          app_guid: { type: 'string', required: true },
          service_instance_guid: { type: 'string', required: true },
          parameters: { type: 'hash', required: false },
          name: { type: 'string', required: false },
        })
      end

      it do
        expect(ServiceBindingsController).to have_updatable_attributes({
          app_guid: { type: 'string' },
          service_instance_guid: { type: 'string' },
          parameters: { type: 'hash', required: false },
          name: { type: 'string', required: false },
        })
      end
    end

    let(:guid_pattern) { '[[:alnum:]-]+' }
    let(:bind_status) { 200 }
    let(:bind_body) { { credentials: credentials } }
    let(:unbind_status) { 200 }
    let(:unbind_body) { {} }
    let(:last_operation_status) { 200 }
    let(:last_operation_body) { { state: 'in progress' } }
    let(:credentials) do
      { 'foo' => 'bar' }
    end

    def broker_url(broker)
      broker.broker_url
    end

    def stub_requests(broker)
      stub_request(:put, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
        with(basic_auth: basic_auth(service_broker: broker)).
        to_return(status: bind_status, body: bind_body.to_json)
      stub_request(:delete, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
        with(basic_auth: basic_auth(service_broker: broker)).
        to_return(status: unbind_status, body: unbind_body.to_json)
      stub_request(:get, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}/last_operation}).
        with(basic_auth: basic_auth(service_broker: broker)).
        to_return(status: last_operation_status, body: last_operation_body.to_json)
    end

    def bind_url_regex(opts={})
      service_binding = opts[:service_binding]
      service_binding_guid = service_binding.try(:guid) || guid_pattern
      service_instance = opts[:service_instance] || service_binding.try(:service_instance)
      service_instance_guid = service_instance.try(:guid) || guid_pattern
      broker = opts[:service_broker] || service_instance.service_plan.service.service_broker
      if opts[:accepts_incomplete]
        query_params = '?accepts_incomplete=true'
      end
      %r{#{broker_url(broker)}/v2/service_instances/#{service_instance_guid}/service_bindings/#{service_binding_guid}#{query_params}}
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @process_a = ProcessModelFactory.make(space: @space_a)
        @service_instance_a = ManagedServiceInstance.make

        @service_instance_a.add_shared_space(@space_a)

        @obj_a = ServiceBinding.make(
          app: @process_a.app,
          service_instance: @service_instance_a
        )

        @process_b = ProcessModelFactory.make(space: @space_b)
        @service_instance_b = ManagedServiceInstance.make(space: @space_b)
        @obj_b = ServiceBinding.make(
          app: @process_b.app,
          service_instance: @service_instance_b
        )
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 1
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'permission enumeration', 'OrgUser',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 0
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'permission enumeration', 'BillingManager',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 0
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'permission enumeration', 'Auditor',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 0
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 1
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 1
        end

        describe 'Developer in service instance space' do
          let(:member_a) { make_developer_for_space(@service_instance_a.space) }
          let(:member_b) { make_developer_for_space(@service_instance_b.space) }

          include_examples 'permission enumeration', 'Developer in service instance space',
            name: 'service binding',
            path: '/v2/service_bindings',
            enumerate: 0
        end
      end
    end

    describe 'POST /v2/service_bindings/' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:process) { ProcessModelFactory.make(space: space) }

      before { set_current_user(developer) }

      shared_examples 'BindableServiceInstance' do
        it 'binds a service instance to an app' do
          post '/v2/service_bindings', req.to_json
          expect(last_response).to have_status_code(201)
          expect(last_response.headers).not_to include('X-Cf-Warnings')

          binding = ServiceBinding.last
          expect(binding.credentials).to eq(credentials)
        end

        context 'when given a valid name' do
          before do
            req[:name] = 'foo'
          end

          it 'binds a service instance with given name to an app' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code(201)
            expect(parsed_response['entity']).to include('name' => 'foo')

            binding = ServiceBinding.last
            expect(binding.name).to eq('foo')
          end
        end

        it 'creates an audit event upon binding' do
          email = 'email@example.com'
          set_current_user(developer, email: email)
          post '/v2/service_bindings', req.to_json

          service_binding = ServiceBinding.last

          event = Event.first(type: 'audit.service_binding.create')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('')
          expect(event.space_guid).to eq(space.guid)
          expect(event.organization_guid).to eq(space.organization.guid)

          expect(event.metadata).to include({
            'request' => {
              'type'          => 'app',
              'name'          => nil,
              'relationships' => {
                'app' => {
                  'data' => { 'guid' => req[:app_guid] }
                },
                'service_instance' => {
                  'data' => { 'guid' => req[:service_instance_guid] }
                },
              },
              'data' => '[PRIVATE DATA HIDDEN]'
            }
          })
        end

        context 'when the app does not exist' do
          it 'returns CF-AppNotFound' do
            post '/v2/service_bindings', { app_guid: 'not-found', service_instance_guid: service_instance.guid }.to_json

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-AppNotFound')
            expect(last_response.status).to eq(404)
          end

          context 'because it maps to non-web process' do
            let(:process) { ProcessModelFactory.make(space: space, type: 'non-web') }

            it 'returns CF-AppNotFound' do
              post '/v2/service_bindings', { app_guid: process.guid, service_instance_guid: service_instance.guid }.to_json

              hash_body = JSON.parse(last_response.body)
              expect(hash_body['error_code']).to eq('CF-AppNotFound')
              expect(last_response.status).to eq(404)
            end
          end
        end

        context 'when the service instance does not exist' do
          let(:req) do
            {
              app_guid:              process.guid,
              service_instance_guid: 'THISISWRONG'
            }.to_json
          end

          it 'returns CF-ServiceInstanceNotFound error' do
            post '/v2/service_bindings', req

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-ServiceInstanceNotFound')
            expect(last_response.status).to eq(404)
          end
        end

        context 'when the user is not a SpaceDeveloper' do
          let(:req) do
            {
              app_guid:              process.guid,
              service_instance_guid: service_instance.guid
            }.to_json
          end

          before do
            set_current_user(User.make)
          end

          it 'returns 403' do
            post '/v2/service_bindings', req
            expect(last_response.status).to eq(403)
          end
        end

        context 'when attempting to bind and the service binding already exists' do
          before do
            ServiceBinding.make(app: process.app, service_instance: service_instance)
          end

          it 'returns a ServiceBindingAppServiceTaken error' do
            post '/v2/service_bindings', req.to_json
            expect(last_response.status).to eq(400)
            expect(decoded_response['error_code']).to eq('CF-ServiceBindingAppServiceTaken')
          end
        end
      end

      context 'for user provided instances' do
        let(:service_instance) { UserProvidedServiceInstance.make(space: space, credentials: credentials) }
        let(:req) do
          {
            app_guid:              process.guid,
            service_instance_guid: service_instance.guid,
            parameters:            params
          }
        end
        let(:params) { nil }

        it_behaves_like 'BindableServiceInstance'

        context 'when the client passes arbitrary params' do
          let(:params_warning) { CGI.escape('Configuration parameters are ignored for bindings to user-provided service instances.') }
          let(:params) { { 'key' => 'value' } }

          it 'does not use the arbitrary params and warns the user' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code 201
            expect(last_response.headers).to include('X-Cf-Warnings')
            expect(last_response.headers['X-Cf-Warnings']).to include(params_warning)
          end
        end

        context 'when the client passes empty params' do
          let(:params) { {} }

          it 'does not warn the user' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code 201
            expect(last_response.headers).not_to include('X-Cf-Warnings')
          end
        end

        context 'when the client passes no params' do
          it 'does not warn the user' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code 201
            expect(last_response.headers).not_to include('X-Cf-Warnings')
          end
        end
      end

      context 'for managed instances' do
        let(:broker) { service_instance.service.service_broker }
        let(:service) { Service.make(bindings_retrievable: false) }
        let(:service_plan) { ServicePlan.make(service: service) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
        let(:req) do
          {
            app_guid: process.guid,
            service_instance_guid: service_instance.guid
          }
        end

        before do
          stub_requests(broker)
        end

        it_behaves_like 'BindableServiceInstance'

        context 'when the app and service instance are in the same space' do
          it 'sends a bind request to the broker' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code(201)

            binding_endpoint = %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}
            expected_body    = {
              service_id: service_instance.service.broker_provided_id,
              plan_id: service_instance.service_plan.broker_provided_id,
              app_guid: process.guid,
              bind_resource: { app_guid: process.guid, space_guid: process.space.guid, app_annotations: {} },
              context: {
                platform: 'cloudfoundry',
                organization_guid: service_instance.organization.guid,
                space_guid:        service_instance.space.guid,
                organization_name: service_instance.organization.name,
                space_name:        service_instance.space.name,
                organization_annotations: {},
                space_annotations: {}
              }
            }

            expect(service_instance.space.guid).to eq(process.space.guid)

            expect(a_request(:put, binding_endpoint).with(body: expected_body)).to have_been_made
          end
        end

        describe 'asynchronous binding creation' do
          context 'when accepts_incomplete is true' do
            let(:bind_body) { {} }

            before do
              post '/v2/service_bindings?accepts_incomplete=true', req.to_json
            end

            context 'when bindings_retrievable is true' do
              let(:service) { Service.make(bindings_retrievable: true) }

              context 'and the broker returns asynchronously' do
                let(:bind_status) { 202 }

                it 'returns a 202 status code' do
                  expect(last_response).to have_status_code(202)
                end

                it 'saves the binding in the model' do
                  binding = ServiceBinding.last
                  expect(binding.last_operation.state).to eql('in progress')
                end

                it 'returns an in progress service binding response' do
                  expect(decoded_response['entity']['last_operation']['type']).to eq('create')
                  expect(decoded_response['entity']['last_operation']['state']).to eq('in progress')
                end

                it 'returns a location header' do
                  expect(last_response.headers['Location']).to match(%r{^/v2/service_bindings/[[:alnum:]-]+$})
                end

                context 'when the service broker returns operation state' do
                  let(:bind_body) { { operation: '123' } }

                  it 'persists the operation state' do
                    binding = ServiceBinding.last
                    expect(binding.last_operation.broker_provided_operation).to eq('123')
                  end
                end

                context 'when bindings_retrievable is false' do
                  let(:service) { Service.make(bindings_retrievable: false) }

                  it 'should throw invalid service binding error' do
                    expect(last_response).to have_status_code(400)
                    expect(decoded_response['error_code']).to eq 'CF-ServiceBindingInvalid'
                    expect(decoded_response['description']).to match('Could not create asynchronous binding when bindings_retrievable is false.')
                  end
                end

                context 'when attempting to bind and the service binding already exists' do
                  it 'returns a ServiceBindingAppServiceTaken error' do
                    post '/v2/service_bindings?accepts_incomplete=true', req.to_json

                    expect(last_response.status).to eq(400)
                    expect(decoded_response['error_code']).to eq('CF-ServiceBindingAppServiceTaken')
                    expect(decoded_response['description']).to eq('The app is already bound to the service.')
                  end
                end
              end

              context 'and the broker is synchronous' do
                let(:bind_status) { 201 }

                it 'returns a 201 status code' do
                  expect(last_response).to have_status_code(201)
                end
              end
            end
          end

          context 'when accepts_incomplete is false' do
            it 'returns a 201 status code' do
              post '/v2/service_bindings?accepts_incomplete=false', req.to_json
              expect(last_response).to have_status_code(201)
            end

            context 'and the broker only supports asynchronous request' do
              let(:bind_status) { 422 }
              let(:bind_body) { { error: 'AsyncRequired' } }

              it 'returns a 400 status code' do
                post '/v2/service_bindings?accepts_incomplete=false', req.to_json
                expect(last_response).to have_status_code(400)
                expect(decoded_response['error_code']).to eq 'CF-AsyncRequired'
              end
            end

            context 'and the broker is spec-incompliant and returns asynchronously anyway' do
              let(:bind_status) { 202 }
              let(:service) { Service.make(bindings_retrievable: true) }

              it 'returns a 502 status code' do
                post '/v2/service_bindings?accepts_incomplete=false', req.to_json
                expect(last_response).to have_status_code(502)
                expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerRespondedAsyncWhenNotAllowed'
                expected_description = 'The service broker responded asynchronously to a request, but the accepts_incomplete query parameter was false or not given.'
                expect(decoded_response['description']).to eq expected_description

                expect(a_request(:delete, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}})).
                  to have_been_made
              end
            end
          end

          context 'when accepts_incomplete is not set' do
            context 'and the broker only supports asynchronous request' do
              let(:bind_status) { 422 }
              let(:bind_body) { { error: 'AsyncRequired' } }

              it 'returns a 400 status code' do
                post '/v2/service_bindings', req.to_json
                expect(last_response).to have_status_code(400)
                expect(decoded_response['error_code']).to eq 'CF-AsyncRequired'
              end
            end
          end

          context 'when accepts_incomplete is not a bool' do
            it 'returns a 400 status code' do
              post '/v2/service_bindings?accepts_incomplete=not_a_bool', req.to_json
              expect(last_response).to have_status_code(400)

              expect(a_request(:put, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}})).
                to_not have_been_made
            end
          end
        end

        context 'when the app is in a space that the service instance is shared to' do
          let(:shared_from_space) { Space.make }
          let(:service_instance) { ManagedServiceInstance.make(space: shared_from_space) }

          before do
            service_instance.add_shared_space(space)
          end

          it 'sends a bind request to the broker' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code(201)

            binding_endpoint = %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}
            expected_body    = {
              service_id: service_instance.service.broker_provided_id,
              plan_id: service_instance.service_plan.broker_provided_id,
              app_guid: process.guid,
              bind_resource: { app_guid: process.guid, space_guid: process.space.guid, app_annotations: {} },
              context: {
                platform: 'cloudfoundry',
                organization_guid: service_instance.organization.guid,
                space_guid:        service_instance.space.guid,
                organization_name: service_instance.organization.name,
                space_name:        service_instance.space.name,
                organization_annotations: {},
                space_annotations: {}
              }
            }

            expect(service_instance.space.guid).not_to eq(process.space.guid)

            expect(a_request(:put, binding_endpoint).with(body: expected_body)).to have_been_made
          end
        end

        context 'when the client provides arbitrary parameters' do
          let(:parameters) { { 'key' => 'value' } }
          let(:req) do
            {
              app_guid: process.guid,
              service_instance_guid: service_instance.guid,
              parameters: parameters
            }
          end

          it 'sends the parameters in the request to the broker' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code(201)
            expect(last_response.headers).not_to include('X-Cf-Warnings')
            binding_endpoint = %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}
            expect(a_request(:put, binding_endpoint).with(body: hash_including(parameters: parameters))).to have_been_made
          end
        end

        shared_examples 'UnbindableServiceInstance' do
          it 'raises UnbindableService error' do
            post '/v2/service_bindings', req.to_json

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-UnbindableService')
            expect(last_response).to have_status_code(400)
          end

          it 'does not send a bind request to broker' do
            post '/v2/service_bindings', req.to_json

            expect(a_request(:put, bind_url_regex(service_instance: service_instance))).to_not have_been_made
          end
        end

        context 'when it is an instance of an unbindable service' do
          before do
            service_instance.service.bindable = false
            service_instance.service.save
          end

          it_behaves_like 'UnbindableServiceInstance'
        end

        context 'when it is an instance of an unbindable service plan' do
          before do
            service_instance.service_plan.bindable = false
            service_instance.service_plan.save
          end

          it_behaves_like 'UnbindableServiceInstance'
        end

        context 'when the instance operation is in progress' do
          let(:request_body) do
            {
              app_guid: process.guid,
              service_instance_guid: service_instance.guid
            }.to_json
          end

          before do
            service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
          end

          it 'does not tell the service broker to bind the service' do
            post '/v2/service_bindings', request_body

            expect(a_request(:put, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}})).
              to_not have_been_made
          end

          it 'does not trigger orphan mitigation' do
            post '/v2/service_bindings', request_body

            orphan_mitigation_job = Delayed::Job.first
            expect(orphan_mitigation_job).to be_nil

            expect(a_request(:delete, bind_url_regex(service_instance: service_instance))).not_to have_been_made
          end

          it 'should show an error message for create bind operation' do
            post '/v2/service_bindings', request_body
            expect(last_response).to have_status_code 409
            expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
          end
        end

        context 'when volume_mount is required and volume_services_enabled is disabled' do
          let(:service_instance) { ManagedServiceInstance.make(:volume_mount, space: space) }

          before do
            TestConfig.config[:volume_services_enabled] = false
          end

          it 'returns CF-VolumeMountServiceDisabled' do
            post '/v2/service_bindings', req.to_json

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-VolumeMountServiceDisabled')
            expect(last_response.status).to eq(403)
          end
        end

        describe 'locking the instance as a result of binding' do
          context 'when the instance has a previous operation' do
            before do
              service_instance.service_instance_operation = ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
              service_instance.save
            end

            it 'reverts the last_operation of the instance to its previous operation' do
              req = {
                app_guid: process.guid,
                service_instance_guid: service_instance.guid
              }.to_json

              post '/v2/service_bindings', req
              expect(service_instance.last_operation.state).to eq 'succeeded'
              expect(service_instance.last_operation.type).to eq 'create'
            end
          end

          context 'when the instance does not have a last_operation' do
            before do
              service_instance.service_instance_operation = nil
              service_instance.save
            end

            it 'does not save a last_operation' do
              req = {
                app_guid: process.guid,
                service_instance_guid: service_instance.guid
              }.to_json

              post '/v2/service_bindings', req
              expect(service_instance.refresh.last_operation).to be_nil
            end
          end
        end

        describe 'binding errors' do
          subject(:make_request) do
            req = {
              app_guid: process.guid,
              service_instance_guid: service_instance.guid
            }.to_json
            post '/v2/service_bindings', req
          end

          context 'when attempting to bind and the service binding already exists' do
            let(:req) do
              {
                app_guid:              process.guid,
                service_instance_guid: service_instance.guid
              }.to_json
            end

            before do
              ServiceBinding.make(app: process.app, service_instance: service_instance)
            end

            it 'does not send a bind request to broker' do
              make_request
              expect(a_request(:put, bind_url_regex(service_instance: service_instance))).to_not have_been_made
            end
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

          context 'when the broker returns a volume_mounts and the service does not require one' do
            let(:bind_body) { { 'volume_mounts' => [{ thing: 'other thing' }] } }

            it 'returns CF-VolumeMountServiceDisabled' do
              make_request
              expect(last_response).to have_status_code 502
              expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerInvalidVolumeMounts'
              post '/v2/service_bindings', req.to_json
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
    end

    describe 'DELETE /v2/service_bindings/:service_binding_guid' do
      let(:service_binding) { ServiceBinding.make(service_instance: service_instance, app: process.app) }
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:process) { ProcessModelFactory.make(space: space) }

      before do
        set_current_user(developer)
      end

      shared_examples 'BindableServiceInstance' do
        it 'returns an empty response body' do
          delete "/v2/service_bindings/#{service_binding.guid}"
          expect(last_response).to have_status_code 204
          expect(last_response.body).to be_empty
        end

        it 'unbinds a service instance from an app' do
          delete "/v2/service_bindings/#{service_binding.guid}"
          expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
        end

        it 'records an audit event after the binding has been deleted' do
          email = 'email@example.com'
          space = service_binding.service_instance.space
          set_current_user(developer, email: email)

          delete "/v2/service_bindings/#{service_binding.guid}"

          event = Event.first(type: 'audit.service_binding.delete')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('')
          expect(event.space_guid).to eq(space.guid)
          expect(event.organization_guid).to eq(space.organization.guid)

          expect(event.metadata).to include({})
        end

        context 'when there are warnings from deleting the binding' do
          before do
            service_binding_deleter = instance_double(ServiceBindingDelete)

            allow(ServiceBindingDelete).to receive(:new).and_return(service_binding_deleter)
            allow(service_binding_deleter).to receive(:foreground_delete_request).and_return(['warning-1', 'warning-2'])
          end

          it 'includes the warnings in the X-Cf-Warnings header' do
            delete "/v2/service_bindings/#{service_binding.guid}"

            expect(last_response).to have_status_code(204)
            expect(last_response.headers).to include('X-Cf-Warnings')
            expect(last_response.headers['X-Cf-Warnings']).to include('warning-1,warning-2')
          end
        end

        context 'when there is an error raised from deleting the binding' do
          before do
            service_binding_deleter = instance_double(ServiceBindingDelete)

            allow(ServiceBindingDelete).to receive(:new).and_return(service_binding_deleter)
            allow(service_binding_deleter).to receive(:foreground_delete_request).and_raise(CloudController::Errors::ApiError.new_from_details('ServiceBrokerAsyncRequired'))
          end

          it 'does not rescue the error' do
            delete "/v2/service_bindings/#{service_binding.guid}"

            expect(last_response).to have_status_code(400)
            hash_body = JSON.parse(last_response.body)
            expect(hash_body['description']).to eq('This service plan requires client support for asynchronous service operations.')
          end
        end

        context 'when the user does not belong to the space' do
          it 'returns a 403' do
            set_current_user(User.make)

            delete "/v2/service_bindings/#{service_binding.guid}"
            expect(last_response).to have_status_code(403)
          end
        end

        context 'when the service binding does not exist' do
          it 'returns 404' do
            delete '/v2/service_bindings/not-found'
            expect(last_response).to have_status_code 404
          end
        end
      end

      context 'for user provided instances' do
        let(:service_instance) { UserProvidedServiceInstance.make(space: space, credentials: credentials) }
        let(:req) do
          {
            app_guid:              process.guid,
            service_instance_guid: service_instance.guid
          }
        end

        it_behaves_like 'BindableServiceInstance'
      end

      context 'for managed instances' do
        let(:broker) { service_instance.service.service_broker }
        let(:service_instance) { ManagedServiceInstance.make(space: space) }
        let(:req) do
          {
            app_guid: process.guid,
            service_instance_guid: service_instance.guid
          }
        end

        before do
          stub_requests(service_binding.service_instance.service.service_broker)
        end

        it_behaves_like 'BindableServiceInstance'

        it 'sends an unbind request to the broker' do
          delete "/v2/service_bindings/#{service_binding.guid}"
          expect(a_request(:delete, bind_url_regex(service_binding: service_binding))).to have_been_made
        end

        describe 'accepts_incomplete' do
          context 'when accepts_incomplete is true' do
            context 'when the broker responds asynchronously' do
              let(:unbind_status) { 202 }

              it 'returns a 202 status code' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=true"
                expect(last_response).to have_status_code(202)
              end

              it 'passess accepts_incomplete flag to the broker' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=true"
                expect(a_request(:delete, unbind_url(service_binding, accepts_incomplete: true))).to have_been_made
              end

              it 'updates the binding operation in the model' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=true"

                service_binding.reload

                expect(service_binding.last_operation.type).to eql('delete')
                expect(service_binding.last_operation.state).to eql('in progress')
              end

              it 'indicates the service binding is being deleted' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=true"

                expect(last_response.headers['Location']).to eq "/v2/service_bindings/#{service_binding.guid}"

                expect(decoded_response['entity']['last_operation']).to be
                expect(decoded_response['entity']['last_operation']['type']).to eq('delete')
                expect(decoded_response['entity']['last_operation']['state']).to eq('in progress')
              end
            end

            context 'when the broker responds synchronously' do
              let(:unbind_status) { 200 }
              let(:unbind_body) { {} }

              it 'returns 204 status code' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=true"

                expect(last_response).to have_status_code(204)
              end
            end
          end

          context 'when accepts_incomplete is false' do
            it 'returns a 204 status code' do
              delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=false"
              expect(last_response).to have_status_code(204)
            end

            context 'when the broker responds asynchronously' do
              let(:unbind_status) { 202 }
              let(:warning) do
                CGI.escape(['The service broker responded asynchronously to the unbind request, but the accepts_incomplete query parameter was false or not given.',
                            'The service binding may not have been successfully deleted on the service broker.'].join(' '))
              end

              it 'returns a 204 status code' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=false"

                expect(last_response).to have_status_code(204)
              end

              it 'should warn the user about the misbehaving broker' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=false"

                expect(last_response.headers).to include('X-Cf-Warnings')
                expect(last_response.headers['X-Cf-Warnings']).to include(warning)
              end
            end

            context 'and the broker only supports asynchronous request' do
              let(:unbind_status) { 422 }
              let(:unbind_body) { { error: 'AsyncRequired' } }

              it 'returns a 400 status code' do
                delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=false"
                expect(last_response).to have_status_code(400)
                expect(decoded_response['error_code']).to eq 'CF-AsyncRequired'
              end
            end
          end

          context 'and when accepts_incomplete is not set' do
            context 'and when the broker only supports asynchronous request' do
              let(:unbind_status) { 422 }
              let(:unbind_body) { { error: 'AsyncRequired' } }

              it 'returns a 400 status code' do
                delete "/v2/service_bindings/#{service_binding.guid}"
                expect(last_response).to have_status_code(400)
                expect(decoded_response['error_code']).to eq 'CF-AsyncRequired'
              end
            end
          end

          context 'and when the parameter is not a bool' do
            it 'returns a 400 status code' do
              delete "/v2/service_bindings/#{service_binding.guid}?accepts_incomplete=not_a_bool"
              expect(last_response).to have_status_code(400)

              expect(a_request(:delete, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}})).
                to_not have_been_made
            end

            context 'when ?async=true' do
              context 'and when the parameter is not a bool' do
                it 'returns a 400 status code' do
                  delete "/v2/service_bindings/#{service_binding.guid}?async=true&accepts_incomplete=not_a_bool"
                  expect(last_response).to have_status_code(400)

                  expect(a_request(:delete, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}})).
                    to_not have_been_made
                end
              end
            end
          end
        end

        describe 'locking the service instance of the binding' do
          context 'when the instance does not have a last_operation' do
            before do
              service_binding.service_instance.service_instance_operation = nil
              service_binding.service_instance.save
            end

            it 'does not save a last_operation' do
              service_instance = service_binding.service_instance

              delete "/v2/service_bindings/#{service_binding.guid}"
              expect(service_instance.refresh.last_operation).to be_nil
            end

            context 'when ?async=true' do
              it 'does not save a last_operation' do
                service_instance = service_binding.service_instance

                delete "/v2/service_bindings/#{service_binding.guid}?async=true"
                expect(service_binding).not_to be_nil
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::DeleteActionJob

                expect(service_instance.refresh.last_operation).to be_nil
              end
            end
          end

          context 'when the instance has a last_operation' do
            before do
              service_binding.service_instance.service_instance_operation = ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
              service_binding.service_instance.save
            end

            it 'reverts to the previous last_operation' do
              service_instance = service_binding.service_instance

              delete "/v2/service_bindings/#{service_binding.guid}"
              expect(service_instance.refresh.last_operation.state).to eq 'succeeded'
              expect(service_instance.refresh.last_operation.type).to eq 'create'
            end

            context 'when ?async=true' do
              it 'reverts to the previous last_operation' do
                service_instance = service_binding.service_instance

                delete "/v2/service_bindings/#{service_binding.guid}?async=true"
                expect(service_binding).not_to be_nil
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::DeleteActionJob

                expect(service_instance.refresh.last_operation.state).to eq 'succeeded'
                expect(service_instance.refresh.last_operation.type).to eq 'create'
              end
            end
          end
        end

        context 'when a binding has operation in progress' do
          let(:last_operation) { ServiceBindingOperation.make(state: 'in progress') }

          before do
            service_binding.service_binding_operation = last_operation
            service_binding.save
          end

          it 'should be able to trigger delete binding' do
            delete "/v2/service_bindings/#{service_binding.guid}"
            expect(last_response).to have_status_code 204
            expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
          end
        end

        context 'with ?async=true' do
          it 'returns a job id' do
            delete "/v2/service_bindings/#{service_binding.guid}?async=true"
            expect(last_response.status).to eq 202
            expect(decoded_response['entity']['guid']).to be
            expect(decoded_response['entity']['status']).to eq 'queued'
          end

          it "passes the invoking user's identity to the service broker client" do
            delete "/v2/service_bindings/#{service_binding.guid}?async=true"
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(a_request(:delete, bind_url_regex(service_binding: service_binding)).with { |request|
              request.headers['X-Broker-Api-Originating-Identity'].match(/^cloudfoundry [a-zA-Z0-9]+={0,3}$/)
            }).to have_been_made
          end
        end

        context 'when the instance operation is in progress' do
          let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
          before do
            service_instance.service_instance_operation = last_operation
            service_instance.save
          end

          it 'should show an error message for unbind operation' do
            delete "/v2/service_bindings/#{service_binding.guid}"
            expect(last_response).to have_status_code 409
            expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
            expect(ServiceBinding.find(guid: service_binding.guid)).not_to be_nil
          end
        end

        context 'when the broker returns an error' do
          before do
            stub_unbind(service_binding, status: 500)
          end

          it 'is decorated with service instance information' do
            delete "/v2/service_bindings/#{service_binding.guid}"

            expect(decoded_response['description']).to(
              include("An unbind operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} failed"))
          end
        end
      end
    end

    describe 'GET', '/v2/service_bindings?inline-relations-depth=1', regression: true do
      let(:space) { Space.make }
      let(:managed_service_instance) { ManagedServiceInstance.make(space: space) }
      let(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
      let(:process) { ProcessModelFactory.make(space: space) }
      let(:developer) { make_developer_for_space(space) }

      it 'returns both user provided and managed service instances' do
        set_current_user(developer)
        ServiceBinding.make(service_instance: managed_service_instance, app: process.app)
        ServiceBinding.make(service_instance: user_provided_service_instance, app: process.app, name: 'service-binding-name')

        get '/v2/service_bindings?inline-relations-depth=1'
        expect(last_response.status).to eql(200)

        service_bindings = decoded_response['resources']

        service_instance_guids = service_bindings.map do |res|
          res['entity']['service_instance']['metadata']['guid']
        end
        expect(service_instance_guids).to match_array([
          managed_service_instance.guid,
          user_provided_service_instance.guid,
        ])

        service_instance_names = service_bindings.map do |res|
          res['entity']['name']
        end
        expect(service_instance_names).to match_array([
          nil,
          'service-binding-name',
        ])
      end

      context 'when service-bindings have names' do
        let(:process1) { ProcessModelFactory.make(space: space, name: 'process1') }
        let(:process2) { ProcessModelFactory.make(space: space, name: 'process2') }
        let(:process3) { ProcessModelFactory.make(space: space, name: 'process3') }

        it 'can query service-bindings by name' do
          set_current_user(developer)
          ServiceBinding.make(service_instance: managed_service_instance, app: process1.app, name: 'potato')
          ServiceBinding.make(service_instance: managed_service_instance, app: process2.app, name: '3-ring')
          ServiceBinding.make(service_instance: managed_service_instance, app: process3.app, name: 'potato')

          get '/v2/service_bindings?inline-relations-depth=1&q=name:3-ring'
          expect(last_response.status).to eq(200), last_response.body
          service_bindings = decoded_response['resources']
          expect(service_bindings.size).to eq(1)
          entity = service_bindings[0]['entity']
          expect(entity['app_guid']).to eq(process2.app.guid)
          expect(entity['service_instance_guid']).to eq(managed_service_instance.guid)
          expect(entity['name']).to eq('3-ring')

          get '/v2/service_bindings?q=name:potato'
          expect(last_response.status).to eq(200), last_response.body
          expect(decoded_response['prev_url']).to be_nil
          expect(decoded_response['next_url']).to be_nil
          service_bindings = decoded_response['resources']
          expect(service_bindings.size).to eq(2)
          expect(service_bindings.map { |x| x['entity']['app_guid'] }).to match_array([process1.app.guid, process3.app.guid])
          expect(service_bindings.map { |x| x['entity']['service_instance_guid'] }).to match_array([managed_service_instance.guid, managed_service_instance.guid])
          expect(service_bindings.map { |x| x['entity']['name'] }).to match_array(['potato', 'potato'])
        end

        context 'when there are many service-bindings per service-instance' do
          let(:processes) { 8.times.to_a.map { |i| ProcessModelFactory.make(space: space, name: "process#{i}") } }
          before do
            set_current_user(developer)
            6.times { |i| ServiceBinding.make(service_instance: managed_service_instance, app: processes[i].app, name: 'potato') }
            ServiceBinding.make(service_instance: managed_service_instance, app: processes[6].app, name: '3-ring')
            ServiceBinding.make(service_instance: managed_service_instance, app: processes[7].app, name: '3-ring')
          end

          it 'can set the next_url and prev_url links' do
            get '/v2/service_bindings?results-per-page=2&page=1&q=name:potato'

            expect(last_response.status).to eq(200), last_response.body
            expect(decoded_response['prev_url']).to be(nil)
            next_url = decoded_response['next_url']
            expect(next_url).to match(%r{^/v2/service_bindings\?(?=.*page=2).*q=name:potato})
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(2)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(processes[0].app.guid)
            expect(entity['name']).to eq('potato')
            entity = service_bindings[1]['entity']
            expect(entity['app_guid']).to eq(processes[1].app.guid)
            expect(entity['name']).to eq('potato')

            get next_url

            expect(last_response.status).to eq(200), last_response.body
            expect(decoded_response['prev_url']).to match(/(?=.*?page=1\b).*q=name:potato/)
            next_url = decoded_response['next_url']
            expect(next_url).to match(/(?=.*?page=3).*q=name:potato/)
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(2)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(processes[2].app.guid)
            expect(entity['name']).to eq('potato')
            entity = service_bindings[1]['entity']
            expect(entity['app_guid']).to eq(processes[3].app.guid)
            expect(entity['name']).to eq('potato')

            get next_url

            expect(last_response.status).to eq(200), last_response.body
            expect(decoded_response['prev_url']).to match(/(?=.*?page=2\b).*q=name:potato/)
            expect(decoded_response['next_url']).to be_nil
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(2)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(processes[4].app.guid)
            expect(entity['name']).to eq('potato')
            entity = service_bindings[1]['entity']
            expect(entity['app_guid']).to eq(processes[5].app.guid)
            expect(entity['name']).to eq('potato')

            get '/v2/service_bindings?results-per-page=2&page=1&q=name:3-ring'

            expect(last_response.status).to eq(200), last_response.body
            expect(decoded_response['prev_url']).to be_nil
            expect(decoded_response['next_url']).to be_nil
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(2)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(processes[6].app.guid)
            expect(entity['name']).to eq('3-ring')
            entity = service_bindings[1]['entity']
            expect(entity['app_guid']).to eq(processes[7].app.guid)
            expect(entity['name']).to eq('3-ring')
          end
        end
      end

      context 'when there are service-instances in multiple spaces' do
        let(:space1) { Space.make }
        let(:process1) { ProcessModelFactory.make(space: space1) }
        let(:developer1) { make_developer_for_space(space1) }
        let(:si1) { ManagedServiceInstance.make(space: space1) }

        let(:space2) { Space.make }
        let(:process2) { ProcessModelFactory.make(space: space2) }
        let(:developer2) { make_developer_for_space(space2) }
        let(:si2) { ManagedServiceInstance.make(space: space2) }

        context 'when developer in one space tries to bind a service-instance from another space' do
          before do
            set_current_user(developer1)
          end

          it 'raises a SpaceMismatch error' do
            req = {
              app_guid:              process1.guid,
              service_instance_guid: si2.guid,
              name: '3-ring',
            }
            post '/v2/service_bindings', req.to_json
            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to eq('VCAP::CloudController::ServiceBindingCreate::SpaceMismatch')
            expect(decoded_response['error_code']).to eq('CF-ServiceBindingAppServiceTaken')
          end
        end

        context 'when both developers bind some service-instances' do
          before do
            ServiceBinding.make(service_instance: si1, app: process1.app, name: 'binding')
            ServiceBinding.make(service_instance: si2, app: process2.app, name: 'binding')
          end
          it 'developer1 can see only bindings in space1' do
            set_current_user(developer1)
            get '/v2/service_bindings?q=name:binding'
            expect(last_response.status).to eq(200), last_response.body
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(1)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(process1.app.guid)
            expect(entity['name']).to eq('binding')
            expect(entity['service_instance_guid']).to eq(si1.guid)
          end

          it 'developer2 can see only bindings in space2' do
            set_current_user(developer2)
            get '/v2/service_bindings?q=name:binding'
            expect(last_response.status).to eq(200), last_response.body
            service_bindings = decoded_response['resources']
            expect(service_bindings.size).to eq(1)
            entity = service_bindings[0]['entity']
            expect(entity['app_guid']).to eq(process2.app.guid)
            expect(entity['name']).to eq('binding')
            expect(entity['service_instance_guid']).to eq(si2.guid)
          end
        end
      end

      context 'when the binding has a create operation in progress' do
        before do
          binding = ServiceBinding.make(service_instance: managed_service_instance, app: process.app)
          binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'create', description: 'creating')
          set_current_user(developer)
        end

        it 'returns the in progress state' do
          get '/v2/service_bindings?inline-relations-depth=1'
          expect(last_response).to have_status_code(200)

          service_binding = decoded_response['resources'].first
          expect(service_binding['entity']['last_operation']['type']).to eq('create')
          expect(service_binding['entity']['last_operation']['state']).to eq('in progress')
          expect(service_binding['entity']['last_operation']['description']).to eq('creating')
        end
      end

      context 'when the binding has a delete operation in progress' do
        before do
          binding = ServiceBinding.make(service_instance: managed_service_instance, app: process.app)
          binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'delete', description: 'deleting')
          set_current_user(developer)
        end

        it 'returns the in progress state' do
          get '/v2/service_bindings?inline-relations-depth=1'
          expect(last_response).to have_status_code(200)

          service_binding = decoded_response['resources'].first
          expect(service_binding['entity']['last_operation']['type']).to eq('delete')
          expect(service_binding['entity']['last_operation']['state']).to eq('in progress')
          expect(service_binding['entity']['last_operation']['description']).to eq('deleting')
        end
      end
    end

    describe 'GET', '/v2/service_bindings/:guid/parameters' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when the service binding is valid' do
        let(:service_plan) { ServicePlan.make(service: service) }
        let(:managed_service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
        let(:process) { ProcessModelFactory.make(space: space) }

        context 'when the service has bindings_retrievable set to false' do
          let(:service) { Service.make(bindings_retrievable: false) }

          it 'returns a 400' do
            set_current_user(developer)
            binding = ServiceBinding.make(service_instance: managed_service_instance, app: process.app)

            get "/v2/service_bindings/#{binding.guid}/parameters"
            expect(last_response.status).to eql(400)
            expect(last_response.body).to include('This service does not support fetching service binding parameters.')
          end
        end

        context 'when the service has bindings_retrievable set to true' do
          let(:service) { Service.make(bindings_retrievable: true) }
          let(:broker) { service.service_broker }
          let(:binding) { ServiceBinding.make(service_instance: managed_service_instance, app: process.app) }
          let(:body) { { 'parameters' => { 'foo' => true } }.to_json }
          let(:response_code) { 200 }

          before do
            stub_request(:get, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
              with(basic_auth: basic_auth(service_broker: broker)).
              to_return(status: response_code, body: body)
            set_current_user(developer)
          end

          context 'when the broker has nested binding parameters' do
            let(:body) { { 'parameters' => { 'foo' => { 'bar' => true } } }.to_json }

            it 'returns the parameters' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(200)
              expect(last_response.body).to eql({ 'foo' => { 'bar' => true } }.to_json)
            end
          end

          context 'when the broker returns empty object' do
            let(:body) { {}.to_json }

            it 'returns an empty object' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(200)
              expect(last_response.body).to eql({}.to_json)
            end
          end

          context 'when the brokers response is missing a parameters key but contains other keys' do
            let(:body) { { 'credentials' => {} }.to_json }

            it 'returns an empty object' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(200)
              expect(last_response.body).to eql({}.to_json)
            end
          end

          context 'when the broker returns multiple keys' do
            let(:body) { { 'credentials' => {}, 'parameters' => { 'foo' => 'bar' } }.to_json }

            it 'returns only the parameters' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(200)
              expect(last_response.body).to eql({ 'foo' => 'bar' }.to_json)
            end
          end

          context 'when the broker returns invalid json' do
            let(:body) { '{]' }

            it 'returns 502' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(502)
              hash_body = JSON.parse(last_response.body)
              expect(hash_body['error_code']).to eq('CF-ServiceBrokerResponseMalformed')
            end
          end

          context 'when the broker returns a non-200 response code' do
            let(:response_code) { 500 }

            it 'returns a 502 and an error' do
              get "/v2/service_bindings/#{binding.guid}/parameters"

              expect(last_response.status).to eql(502)
              hash_body = JSON.parse(last_response.body)
              expect(hash_body['error_code']).to eq('CF-ServiceBrokerBadResponse')
            end
          end

          context 'when the broker parameters is not a JSON object' do
            let(:body) { { 'parameters' => true }.to_json }

            it 'returns 502' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(502)
              hash_body = JSON.parse(last_response.body)
              expect(hash_body['error_code']).to eq('CF-ServiceBrokerResponseMalformed')
            end
          end

          context 'when the user has access to the binding of a shared service instance' do
            let(:managed_service_instance) { ManagedServiceInstance.make(space: Space.make, service_plan: service_plan) }

            before do
              managed_service_instance.add_shared_space(space)
            end

            it 'returns the parameters' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(200)
              expect(last_response.body).to eql({ 'foo' => true }.to_json)
            end
          end

          context 'when the user who shared the service instance tries to access binding parameters in the shared to space' do
            let(:source_space) { Space.make }
            let(:managed_service_instance) { ManagedServiceInstance.make(space: source_space, service_plan: service_plan) }
            let(:developer) { make_developer_for_space(source_space) }

            before do
              managed_service_instance.add_shared_space(space)
            end

            it 'returns a 403' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response.status).to eql(403)
            end
          end

          context 'when the service binding has an operation in progress' do
            let(:last_operation) { ServiceBindingOperation.make(state: 'in progress') }

            before do
              binding.service_binding_operation = last_operation
              binding.save
            end

            it 'should show an error message for get parameter operation' do
              get "/v2/service_bindings/#{binding.guid}/parameters"
              expect(last_response).to have_status_code 409
              expect(last_response.body).to match 'AsyncServiceBindingOperationInProgress'
            end
          end

          context 'user permissions' do
            let(:user) { User.make }
            let(:body) { {}.to_json }

            {
              'admin'               => 200,
              'space_developer'     => 200,
              'admin_read_only'     => 200,
              'global_auditor'      => 200,
              'space_manager'       => 200,
              'space_auditor'       => 200,
              'org_manager'         => 200,
              'org_auditor'         => 403,
              'org_billing_manager' => 403,
              'org_user'            => 403,
            }.each do |role, expected_status|
              context "as a(n) #{role} in the binding space" do
                before do
                  set_current_user_as_role(
                    role:   role,
                    org:    space.organization,
                    space:  space,
                    user:   user
                  )
                end

                it "receives a #{expected_status} http status code" do
                  get "/v2/service_bindings/#{binding.guid}/parameters"
                  expect(last_response.status).to eq(expected_status)
                end
              end
            end
          end
        end
      end

      context 'when the binding is for a user provided service' do
        let(:process) { ProcessModelFactory.make(space: space) }
        let(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }

        it 'returns a 400' do
          set_current_user(developer)
          binding = ServiceBinding.make(service_instance: user_provided_service_instance, app: process.app)

          get "/v2/service_bindings/#{binding.guid}/parameters"
          expect(last_response.status).to eql(400)
          expect(last_response.body).to include('This service does not support fetching service binding parameters.')
        end
      end

      context 'when the binding guid is invalid' do
        it 'returns a 404' do
          set_current_user(developer)
          get '/v2/service_bindings/some-bogus-guid/parameters'
          expect(last_response.status).to eql(404)
          expect(last_response.body).to include('The service binding could not be found: some-bogus-guid')
        end
      end

      context 'when the requested binding is a service key' do
        let(:service_key) { ServiceKey.make }

        it 'returns a 404' do
          set_current_user(developer)
          get "/v2/service_bindings/#{service_key.guid}/parameters"
          expect(last_response.status).to eql(404)
          expect(last_response.body).to include("The service binding could not be found: #{service_key.guid}")
        end
      end
    end
  end
end
