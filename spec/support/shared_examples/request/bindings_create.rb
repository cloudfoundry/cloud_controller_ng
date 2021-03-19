RSpec.shared_examples 'service credential binding create endpoint' do |klass, check_app, audit_event_type, display_name|
  describe 'managed instance' do
    let(:api_call) { ->(user_headers) { post '/v3/service_credential_bindings', create_body.to_json, user_headers } }
    let(:job) { VCAP::CloudController::PollableJobModel.last }
    let(:binding) { klass.last }

    describe 'a successful creation' do
      before do
        api_call.call(admin_headers)
      end

      it 'creates a credential binding in the database' do
        expect(binding.app).to eq(app_to_bind_to) if check_app
        expect(binding.service_instance).to eq(service_instance)

        expect(binding.last_operation.state).to eq('in progress')
        expect(binding.last_operation.type).to eq('create')

        expect(binding).to have_labels({ prefix: nil, key: 'foo', value: 'bar' })
        expect(binding).to have_annotations({ prefix: nil, key: 'foz', value: 'baz' })
      end

      it 'responds with a job resource' do
        expect(last_response).to have_status_code(202)
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq("#{display_name}.create")
        expect(job.resource_guid).to eq(binding.guid)
        expect(job.resource_type).to eq('service_credential_binding')

        get "/v3/jobs/#{job.guid}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['guid']).to eq(job.guid)
        binding_link = parsed_response.dig('links', 'service_credential_binding', 'href')
        expect(binding_link).to end_with("/v3/service_credential_bindings/#{binding.guid}")
      end
    end

    describe 'the pollable job' do
      let(:credentials) { { 'password' => 'special sauce' } }
      let(:broker_base_url) { service_instance.service_broker.broker_url }
      let(:broker_bind_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:broker_status_code) { 201 }
      let(:broker_response) { { credentials: credentials } }
      let(:app_binding_attributes) {
        if check_app
          {
            app_guid: app_to_bind_to.guid,
            bind_resource: {
              app_guid: app_to_bind_to.guid,
              space_guid: service_instance.space.guid,
              app_annotations: { 'pre.fix/foo': 'bar' }
            }
          }
        else
          {}
        end
      }
      let(:client_body) do
        {
          context: {
            platform: 'cloudfoundry',
            organization_guid: org.guid,
            organization_name: org.name,
            organization_annotations: { 'pre.fix/foo': 'bar' },
            space_guid: space.guid,
            space_name: space.name,
            space_annotations: { 'pre.fix/baz': 'wow' },
          },
          service_id: service_instance.service_plan.service.unique_id,
          plan_id: service_instance.service_plan.unique_id,
          bind_resource: {
            credential_client_id: 'cc_service_key_client',
          },
        }.merge(app_binding_attributes)
      end

      before do
        api_call.call(headers_for(user, scopes: %w(cloud_controller.admin)))
        expect(last_response).to have_status_code(202)

        stub_request(:put, broker_bind_url).
          with(query: { accepts_incomplete: true }).
          to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
      end

      it 'sends a bind request with the right arguments to the service broker' do
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
        expect(
          a_request(:put, broker_bind_url).
            with(
              body: client_body,
              query: { accepts_incomplete: true },
              headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
            )
        ).to have_been_made.once
      end

      context 'parameters are specified' do
        let(:request_extra) { { parameters: { foo: 'bar' } } }

        it 'sends the parameters to the broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(
            a_request(:put, broker_bind_url).
              with(
                body: client_body.deep_merge(request_extra),
                query: { accepts_incomplete: true }
              )
          ).to have_been_made.once
        end
      end

      context 'when the bind completes synchronously' do
        it 'updates the the binding' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          binding.reload
          expect(binding.credentials).to eq(credentials)
          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('succeeded')
        end

        it 'completes the job' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
        end

        it 'logs an audit event' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          event = VCAP::CloudController::Event.find(type: "audit.#{audit_event_type}.create")
          expect(event).to be
          expect(event.actee).to eq(binding.guid)
          expect(event.actee_name).to eq(binding.name)
          expect(event.data).to include({
            'request' => create_body.with_indifferent_access
          })
        end
      end

      context 'when the broker fails to bind' do
        let(:broker_status_code) { 422 }
        let(:broker_response) { { error: 'RequiresApp' } }

        it 'updates the the binding with a failure' do
          execute_all_jobs(expected_successes: 0, expected_failures: 1)

          binding.reload
          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('failed')
        end

        it 'fails the job' do
          execute_all_jobs(expected_successes: 0, expected_failures: 1)

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
        end
      end

      context 'when the binding completes asynchronously' do
        let(:broker_status_code) { 202 }
        let(:operation) { Sham.guid }
        let(:broker_response) { { operation: operation } }
        let(:broker_binding_last_operation_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}/last_operation" }
        let(:last_operation_status_code) { 200 }
        let(:description) { Sham.description }
        let(:state) { 'in progress' }
        let(:last_operation_body) do
          {
            description: description,
            state: state,
          }
        end

        before do
          stub_request(:get, broker_binding_last_operation_url).
            with(query: hash_including({
              operation: operation
            })).
            to_return(status: last_operation_status_code, body: last_operation_body.to_json, headers: {})
        end

        it 'polls the last operation endpoint' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(
            a_request(:get, broker_binding_last_operation_url).
              with(
                query: {
                  operation: operation,
                  service_id: service_instance.service_plan.service.unique_id,
                  plan_id: service_instance.service_plan.unique_id,
                },
                headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
              )
          ).to have_been_made.once
        end

        it 'updates the binding and job' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq(state)
          expect(binding.last_operation.description).to eq(description)

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
        end

        it 'logs an audit event' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          event = VCAP::CloudController::Event.find(type: "audit.#{audit_event_type}.start_create")
          expect(event).to be
          expect(event.actee).to eq(binding.guid)
          expect(event.data).to include({
            'request' => create_body.with_indifferent_access
          })
        end

        it 'enqueues the next fetch last operation job' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq(1)
        end

        it 'keeps track of the broker operation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq(1)

          Timecop.travel(Time.now + 1.minute)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(
            a_request(:get, broker_binding_last_operation_url).
              with(
                query: {
                operation: operation,
                service_id: service_instance.service_plan.service.unique_id,
                plan_id: service_instance.service_plan.unique_id,
              },
                headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
              )
          ).to have_been_made.twice
        end

        context 'last operation response is 200 OK and indicates success' do
          let(:state) { 'succeeded' }
          let(:fetch_binding_status_code) { 200 }
          let(:credentials) { { password: 'foo' } }
          let(:parameters) { { foo: 'bar', another_foo: 'another_bar' } }

          let(:app_binding_attributes) {
            if check_app
              {
                syslog_drain_url: syslog_drain_url,
              }
            else
              {}
            end
          }

          let(:fetch_binding_body) do
            {
              credentials: credentials,
              parameters: parameters,
              service_id: 'extra-field-service_id-should-ignore',
              name: 'extra-field-name-should-not-update',
            }.merge(app_binding_attributes)
          end

          before do
            stub_request(:get, broker_bind_url).
              to_return(status: fetch_binding_status_code, body: fetch_binding_body.to_json, headers: {})
          end

          it 'fetches the binding' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            expect(
              a_request(:get, broker_bind_url).with(
                headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
              )
            ).to have_been_made.once
          end

          it 'updates the binding and job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq(state)
            expect(binding.last_operation.description).to eq(description)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          end

          it 'updates the binding details with the fetch binding response ignoring extra fields' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(binding.reload.credentials).to eq(credentials.with_indifferent_access)
            expect(binding.syslog_drain_url).to eq(syslog_drain_url) if check_app
            expect(binding.name).to eq(binding_name)
          end

          it 'logs an audit event' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            event = VCAP::CloudController::Event.find(type: "audit.#{audit_event_type}.create")
            expect(event).to be
            expect(event.actee).to eq(binding.guid)
            expect(event.data).to include({
              'request' => create_body.with_indifferent_access
            })
          end

          context 'fetching binding fails ' do
            let(:fetch_binding_status_code) { 404 }
            let(:fetch_binding_body) {}

            it 'fails the job' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('failed')
              expect(binding.last_operation.description).to include('The service broker rejected the request. Status Code: 404 Not Found')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              expect(job.cf_api_error).not_to be_nil
              error = YAML.safe_load(job.cf_api_error)
              expect(error['errors'].first).to include({
                'code' => 10009,
                'title' => 'CF-UnableToPerform',
                'detail' => 'bind could not be completed: The service broker rejected the request. Status Code: 404 Not Found, Body: null',
              })
            end
          end
        end

        it_behaves_like 'binding last operation response handling', 'create'

        context 'binding not retrievable' do
          let(:offering) { VCAP::CloudController::Service.make(bindings_retrievable: false) }

          it 'fails the job with an appropriate error' do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('failed')
            expect(binding.last_operation.description).to eq('The broker responded asynchronously but does not support fetching binding data')

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            expect(job.cf_api_error).not_to be_nil
            error = YAML.safe_load(job.cf_api_error)
            # TODO: check error message
            expect(error['errors'].first).to include({
              'code' => 90001,
              'title' => 'CF-ServiceBindingInvalid',
              'detail' => 'The service binding is invalid: The broker responded asynchronously but does not support fetching binding data',
            })
          end
        end
      end

      context 'orphan mitigation' do
        it_behaves_like 'create binding orphan mitigation' do
          let(:bind_url) { broker_bind_url }
          let(:plan_id) { plan.unique_id }
          let(:offering_id) { offering.unique_id }
        end
      end
    end
  end
end
