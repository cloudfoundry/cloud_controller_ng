require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:app_guid) }
      it { expect(described_class).to be_queryable_by(:service_instance_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          app_guid: { type: 'string', required: true },
          service_instance_guid: { type: 'string', required: true },
          parameters: { type: 'hash', required: false }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          app_guid: { type: 'string' },
          service_instance_guid: { type: 'string' },
          parameters: { type: 'hash', required: false }
        })
      end
    end

    let(:guid_pattern) { '[[:alnum:]-]+' }
    let(:bind_status) { 200 }
    let(:bind_body) { { credentials: credentials } }
    let(:unbind_status) { 200 }
    let(:unbind_body) { {} }
    let(:credentials) do
      { 'foo' => 'bar' }
    end

    def broker_url(broker)
      base_broker_uri = URI.parse(broker.broker_url)
      base_broker_uri.user = broker.auth_username
      base_broker_uri.password = broker.auth_password
      base_broker_uri.to_s
    end

    def stub_requests(broker)
      stub_request(:put, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
        to_return(status: bind_status, body: bind_body.to_json)
      stub_request(:delete, %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
        to_return(status: unbind_status, body: unbind_body.to_json)
    end

    def bind_url_regex(opts={})
      service_binding = opts[:service_binding]
      service_binding_guid = service_binding.try(:guid) || guid_pattern
      service_instance = opts[:service_instance] || service_binding.try(:service_instance)
      service_instance_guid = service_instance.try(:guid) || guid_pattern
      broker = opts[:service_broker] || service_instance.service_plan.service.service_broker
      %r{#{broker_url(broker)}/v2/service_instances/#{service_instance_guid}/service_bindings/#{service_binding_guid}}
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @app_a = AppFactory.make(space: @space_a)
        @service_instance_a = ManagedServiceInstance.make(space: @space_a)
        @obj_a = ServiceBinding.make(
          app: @app_a.app,
          service_instance: @service_instance_a
        )

        @app_b = AppFactory.make(space: @space_b)
        @service_instance_b = ManagedServiceInstance.make(space: @space_b)
        @obj_b = ServiceBinding.make(
          app: @app_b.app,
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
      end
    end

    describe 'create' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:app_obj) { AppFactory.make(space: space) }

      before { set_current_user(developer) }

      context 'for user provided instances' do
        let(:service_instance) { UserProvidedServiceInstance.make(space: space) }
        let(:params) do
          {
            'app_guid' => app_obj.guid,
            'service_instance_guid' => service_instance.guid
          }
        end

        context 'when the client passes arbitrary params' do
          it 'does not use the arbitrary params' do
            body = params.merge(parameters: { 'key' => 'value' })
            post '/v2/service_bindings', body.to_json
            expect(last_response).to have_status_code 201
          end
        end
      end

      context 'for managed instances' do
        let(:broker) { instance.service.service_broker }
        let(:instance) { ManagedServiceInstance.make(space: space) }
        let(:req) do
          {
            app_guid: app_obj.guid,
            service_instance_guid: instance.guid
          }
        end

        before do
          stub_requests(broker)
        end

        it 'binds a service instance to an app' do
          post '/v2/service_bindings', req.to_json
          expect(last_response).to have_status_code(201)

          binding = ServiceBinding.last
          expect(binding.credentials).to eq(credentials)
        end

        it 'sends a bind request to the broker' do
          post '/v2/service_bindings', req.to_json
          expect(last_response).to have_status_code(201)

          binding_endpoint = %r{#{broker_url(broker)}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}
          expected_body    = {
            service_id: instance.service.broker_provided_id,
            plan_id: instance.service_plan.broker_provided_id,
            app_guid: app_obj.guid,
            bind_resource: { app_guid: app_obj.guid }
          }

          expect(a_request(:put, binding_endpoint).with(body: expected_body)).to have_been_made
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
              'relationships' => {
                'app'              => { 'guid' => req[:app_guid] },
                'service_instance' => { 'guid' => req[:service_instance_guid] }
              },
              'data' => 'PRIVATE DATA HIDDEN'
            }
          })
        end

        context 'when the client provides arbitrary parameters' do
          let(:parameters) { { 'key' => 'value' } }
          let(:req) do
            {
              app_guid: app_obj.guid,
              service_instance_guid: instance.guid,
              parameters: parameters
            }
          end

          it 'sends the parameters in the request to the broker' do
            post '/v2/service_bindings', req.to_json
            expect(last_response).to have_status_code(201)
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

            expect(a_request(:put, bind_url_regex(service_instance: instance))).to_not have_been_made
          end
        end

        context 'when it is an instance of an unbindable service' do
          before do
            instance.service.bindable = false
            instance.service.save
          end

          it_behaves_like 'UnbindableServiceInstance'
        end

        context 'when it is an instance of an unbindable service plan' do
          before do
            instance.service_plan.bindable = false
            instance.service_plan.save
          end

          it_behaves_like 'UnbindableServiceInstance'
        end

        context 'when the app does not exist' do
          it 'returns CF-AppNotFound' do
            post '/v2/service_bindings', { app_guid: 'not-found', service_instance_guid: instance.guid }.to_json

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-AppNotFound')
            expect(last_response.status).to eq(404)
          end

          context 'because it maps to non-web process' do
            let(:app_obj) { AppFactory.make(space: space, type: 'non-web') }

            it 'returns CF-AppNotFound' do
              post '/v2/service_bindings', { app_guid: app_obj.guid, service_instance_guid: instance.guid }.to_json

              hash_body = JSON.parse(last_response.body)
              expect(hash_body['error_code']).to eq('CF-AppNotFound')
              expect(last_response.status).to eq(404)
            end
          end
        end

        context 'when the service instance does not exist' do
          let(:req) do
            {
              app_guid:              app_obj.guid,
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
              app_guid:              app_obj.guid,
              service_instance_guid: instance.guid
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

        context 'when the instance operation is in progress' do
          let(:request_body) do
            {
              app_guid: app_obj.guid,
              service_instance_guid: instance.guid
            }.to_json
          end

          before do
            instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
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

            expect(a_request(:delete, bind_url_regex(service_instance: instance))).not_to have_been_made
          end

          it 'should show an error message for create bind operation' do
            post '/v2/service_bindings', request_body
            expect(last_response).to have_status_code 409
            expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
          end
        end

        context 'when volume_mount is required and volume_services_enabled is disabled' do
          let(:instance) { ManagedServiceInstance.make(:volume_mount, space: space) }

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
              instance.service_instance_operation = ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
              instance.save
            end

            it 'reverts the last_operation of the instance to its previous operation' do
              req = {
                app_guid: app_obj.guid,
                service_instance_guid: instance.guid
              }.to_json

              post '/v2/service_bindings', req
              expect(instance.last_operation.state).to eq 'succeeded'
              expect(instance.last_operation.type).to eq 'create'
            end
          end

          context 'when the instance does not have a last_operation' do
            before do
              instance.service_instance_operation = nil
              instance.save
            end

            it 'does not save a last_operation' do
              req = {
                app_guid: app_obj.guid,
                service_instance_guid: instance.guid
              }.to_json

              post '/v2/service_bindings', req
              expect(instance.refresh.last_operation).to be_nil
            end
          end
        end

        describe 'binding errors' do
          subject(:make_request) do
            req = {
              app_guid: app_obj.guid,
              service_instance_guid: instance.guid
            }.to_json
            post '/v2/service_bindings', req
          end

          context 'when attempting to bind and the service binding already exists' do
            let(:req) do
              {
                app_guid:              app_obj.guid,
                service_instance_guid: instance.guid
              }.to_json
            end

            before do
              ServiceBinding.make(app: app_obj.app, service_instance: instance)
            end

            it 'returns a ServiceBindingAppServiceTaken error' do
              make_request
              expect(last_response.status).to eq(400)
              expect(decoded_response['error_code']).to eq('CF-ServiceBindingAppServiceTaken')
            end

            it 'does not send a bind request to broker' do
              make_request
              expect(a_request(:put, bind_url_regex(service_instance: instance))).to_not have_been_made
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
              expect(instance.refresh.last_operation).to be_nil
            end

            context 'when the instance has a last_operation' do
              before do
                instance.service_instance_operation = ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
              end

              it 'rolls back the last_operation of the service instance' do
                make_request
                expect(instance.refresh.last_operation.state).to eq 'succeeded'
                expect(instance.refresh.last_operation.type).to eq 'create'
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
            let(:bind_body) { { 'volume_mounts' => [{ 'thing': 'other thing' }] } }

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

    describe 'DELETE', '/v2/service_bindings/:service_binding_guid' do
      let(:service_binding) { ServiceBinding.make }
      let(:developer) { make_developer_for_space(service_binding.service_instance.space) }

      before do
        stub_requests(service_binding.service_instance.service.service_broker)
        set_current_user(developer)
      end

      it 'returns an empty response body' do
        delete "/v2/service_bindings/#{service_binding.guid}"
        expect(last_response).to have_status_code 204
        expect(last_response.body).to be_empty
      end

      it 'unbinds a service instance from an app' do
        delete "/v2/service_bindings/#{service_binding.guid}"
        expect(ServiceBinding.find(guid: service_binding.guid)).to be_nil
        expect(a_request(:delete, bind_url_regex(service_binding: service_binding))).to have_been_made
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

      context 'with ?async=true' do
        it 'returns a job id' do
          delete "/v2/service_bindings/#{service_binding.guid}?async=true"
          expect(last_response.status).to eq 202
          expect(decoded_response['entity']['guid']).to be
          expect(decoded_response['entity']['status']).to eq 'queued'
        end
      end

      context 'when the instance operation is in progress' do
        let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }
        let(:instance) { ManagedServiceInstance.make }
        let(:service_binding) { ServiceBinding.make(service_instance: instance) }
        before do
          instance.service_instance_operation = last_operation
          instance.save
        end

        it 'should show an error message for unbind operation' do
          delete "/v2/service_bindings/#{service_binding.guid}"
          expect(last_response).to have_status_code 409
          expect(last_response.body).to match 'AsyncServiceInstanceOperationInProgress'
          expect(ServiceBinding.find(guid: service_binding.guid)).not_to be_nil
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

    describe 'GET', '/v2/service_bindings?inline-relations-depth=1', regression: true do
      let(:space) { Space.make }
      let(:managed_service_instance) { ManagedServiceInstance.make(space: space) }
      let(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
      let(:app_obj) { AppFactory.make(space: space) }
      let(:developer) { make_developer_for_space(space) }

      it 'returns both user provided and managed service instances' do
        set_current_user(developer)
        ServiceBinding.make(service_instance: managed_service_instance, app: app_obj.app)
        ServiceBinding.make(service_instance: user_provided_service_instance, app: app_obj.app)

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
      end
    end
  end
end
