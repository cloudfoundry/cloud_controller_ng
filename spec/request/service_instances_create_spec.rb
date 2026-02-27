require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances - Create' do
  include_context 'service instances setup'

  describe 'POST /v3/service_instances' do
    let(:api_call) { ->(user_headers) { post '/v3/service_instances', request_body.to_json, user_headers } }
    let(:space_guid) { space.guid }

    let(:name) { Sham.name }
    let(:type) { 'user-provided' }
    let(:request_body_additions) { {} }
    let(:request_body) do
      {
        type: type,
        name: name,
        relationships: {
          space: {
            data: {
              guid: space_guid
            }
          }
        }
      }.merge(request_body_additions)
    end

    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end

    context 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_create_endpoint(success_code: 201) }
      end

      it_behaves_like 'permissions for create endpoint when organization is suspended', 201
    end

    context 'when service_instance_creation flag is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.create(name: 'service_instance_creation', enabled: false)
      end

      it 'makes non_admins unable to create any type of service' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include({
                    'detail' => 'Feature Disabled: service_instance_creation',
                    'title' => 'CF-FeatureDisabled',
                    'code' => 330_002
                  })
        )
      end

      it 'does not impact admins ability create services' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(201)
      end
    end

    context 'when the request body is invalid' do
      let(:request_body) { { type: 'foo' } }

      it 'says the message is unprocessable' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(
          include({
                    'detail' => "Relationships 'relationships' is not an object, Type must be one of 'managed', 'user-provided', Name must be a string, Name can't be blank",
                    'title' => 'CF-UnprocessableEntity',
                    'code' => 10_008
                  })
        )
      end
    end

    context 'when the space is not readable' do
      it 'fails saying the space cannot be found' do
        request_body[:relationships][:space][:data][:guid] = VCAP::CloudController::Space.make.guid

        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(
          include({
                    'detail' => 'Invalid space. Ensure that the space exists and you have access to it.',
                    'title' => 'CF-UnprocessableEntity',
                    'code' => 10_008
                  })
        )
      end
    end

    context 'user-provided service instance' do
      let(:request_body) do
        {
          type: type,
          name: name,
          relationships: {
            space: {
              data: {
                guid: space_guid
              }
            }
          },
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          tags: %w[foo bar baz],
          syslog_drain_url: 'https://syslog.com/drain',
          route_service_url: 'https://route.com/service',
          metadata: {
            annotations: {
              foo: 'bar'
            },
            labels: {
              baz: 'qux'
            }
          }
        }
      end

      it 'responds with the created object' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(201)
        expect(parsed_response).to match_json_response(
          create_user_provided_json(
            VCAP::CloudController::ServiceInstance.last,
            labels: { baz: 'qux' },
            annotations: { foo: 'bar' },
            last_operation: {
              type: 'create',
              state: 'succeeded',
              description: 'Operation succeeded',
              created_at: iso8601,
              updated_at: iso8601
            }
          )
        )
      end

      it 'creates a service instance in the database' do
        api_call.call(space_dev_headers)

        instance = VCAP::CloudController::ServiceInstance.last

        expect(instance.name).to eq(name)
        expect(instance.syslog_drain_url).to eq('https://syslog.com/drain')
        expect(instance.route_service_url).to eq('https://route.com/service')
        expect(instance.tags).to contain_exactly('foo', 'bar', 'baz')
        expect(instance.credentials).to match({ 'foo' => 'bar', 'baz' => 'qux' })
        expect(instance.space).to eq(space)
        expect(instance.last_operation.type).to eq('create')
        expect(instance.last_operation.state).to eq('succeeded')
        expect(instance).to have_annotations({ prefix: nil, key_name: 'foo', value: 'bar' })
        expect(instance).to have_labels({ prefix: nil, key_name: 'baz', value: 'qux' })
      end

      context 'when the name has already been taken' do
        it 'fails when the same name is already used in this space' do
          VCAP::CloudController::ServiceInstance.make(name:, space:)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => "The service instance name is taken: #{name}.",
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end

        it 'succeeds when the same name is used in another space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: another_space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(201)
        end
      end

      context 'when the route is not https' do
        it 'returns an error' do
          request_body[:route_service_url] = 'http://banana.example.com'
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => 'Route service url must be https',
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end
      end
    end

    context 'managed service instance' do
      let(:type) { 'managed' }
      let(:maintenance_info) do
        {
          version: '1.2.3',
          description: 'amazing version'
        }
      end
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, maintenance_info: maintenance_info) }
      let(:service_plan_guid) { service_plan.guid }
      let(:request_body) do
        {
          type: type,
          name: name,
          relationships: {
            space: {
              data: {
                guid: space_guid
              }
            },
            service_plan: {
              data: {
                guid: service_plan_guid
              }
            }
          },
          parameters: {
            foo: 'bar',
            baz: 'qux'
          },
          tags: %w[foo bar baz],
          metadata: {
            annotations: {
              foo: 'bar',
              'pre.fix/wow': 'baz'
            },
            labels: {
              baz: 'qux'
            }
          }
        }
      end
      let(:instance) { VCAP::CloudController::ServiceInstance.last }
      let(:job) { VCAP::CloudController::PollableJobModel.last }
      let(:mock_logger) { instance_double(Steno::Logger, info: nil) }

      before do
        allow(Steno).to receive(:logger).and_call_original
        allow(Steno).to receive(:logger).with('cc.api').and_return(mock_logger)
      end

      context 'when providing parameters with mixed data types' do
        let(:request_body) do
          "{\"type\":\"managed\",\"name\":\"#{name}\"," \
            "\"relationships\":{\"space\":{\"data\":{\"guid\":\"#{space_guid}\"}},\"service_plan\":{\"data\":{\"guid\":\"#{service_plan_guid}\"}}}," \
            "\"parameters\":#{parameters_mixed_data_types_as_json_string}}"
        end

        it 'correctly parses all data types and sends the desired JSON string to the service broker' do
          post '/v3/service_instances', request_body, space_dev_headers

          expect_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:provision).
            with(instance, hash_including(arbitrary_parameters: parameters_mixed_data_types_as_hash)). # correct internal representation
            and_call_original

          stub_request(:put, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
            with(query: { 'accepts_incomplete' => true }, body: /"parameters":#{Regexp.escape(parameters_mixed_data_types_as_json_string)}/).
            to_return(status: 201, body: '{}')

          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end

      it 'creates a service instance in the database' do
        api_call.call(space_dev_headers)

        expect(instance.name).to eq(name)
        expect(instance.tags).to contain_exactly('foo', 'bar', 'baz')
        expect(instance.space).to eq(space)
        expect(instance.service_plan).to eq(service_plan)

        expect(instance).to have_annotations({ prefix: nil, key_name: 'foo', value: 'bar' }, { prefix: 'pre.fix', key_name: 'wow', value: 'baz' })
        expect(instance).to have_labels({ prefix: nil, key_name: 'baz', value: 'qux' })

        expect(instance.last_operation.type).to eq('create')
        expect(instance.last_operation.state).to eq('initial')
      end

      it 'responds with job resource' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(202)
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_instance.create')
        expect(job.resource_guid).to eq(instance.guid)
        expect(job.resource_type).to eq('service_instances')
      end

      it 'logs the correct names when creating a managed service instance' do
        api_call.call(space_dev_headers)

        expect(mock_logger).to have_received(:info).with(
          "Creating managed service instance with name '#{instance.name}' " \
          "using service plan '#{service_plan.name}' " \
          "from service offering '#{service_plan.service.name}' " \
          "provided by broker '#{service_plan.service.service_broker.name}'."
        )
      end

      context 'when the name has already been taken' do
        it 'fails when the same name is already used in this space' do
          VCAP::CloudController::ServiceInstance.make(name:, space:)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => "The service instance name is taken: #{name}.",
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end

        it 'succeeds when the same name is used in another space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: another_space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(202)
        end
      end

      context 'when the plan is org-restricted' do
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
        end

        it 'can be created in a space in that org' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(202)
          expect(instance.name).to eq(name)
        end
      end

      describe 'unavailable broker' do
        context 'when the service broker does not have state (v2 brokers)' do
          let(:service_broker) { service_plan.service_broker }

          it 'creates a service instance' do
            service_broker.update(state: '')
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(202)
          end
        end

        context 'when there is an operation in progress for the service broker' do
          let(:service_broker) { service_plan.service_broker }

          before do
            service_broker.update(state: broker_state)
          end

          context 'when the service broker is being deleted' do
            let(:broker_state) { VCAP::CloudController::ServiceBrokerStateEnum::DELETE_IN_PROGRESS }

            it 'fails to create a service instance' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => 'The service instance cannot be created because there is an operation in progress for the service broker.',
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end

          context 'when the service broker is synchronising the catalog' do
            let(:broker_state) { VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING }

            it 'fails to create a service instance' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => 'The service instance cannot be created because there is an operation in progress for the service broker.',
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end
        end
      end

      describe 'when db is unavailable' do
        before do
          allow_any_instance_of(VCAP::CloudController::Jobs::Enqueuer).to receive(:enqueue_pollable).and_raise(Sequel::DatabaseDisconnectError)
        end

        it 'raises the appropriate error' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors']).to include(include({
                                                                 'detail' => include('Database connection failure'),
                                                                 'title' => 'CF-ServiceUnavailable',
                                                                 'code' => 10_015
                                                               }))
        end

        it 'does not create a service instance in the database' do
          api_call.call(admin_headers)

          expect(instance).to be_nil
        end
      end

      describe 'service plan checks' do
        context 'does not exist' do
          let(:service_plan_guid) { 'does-not-exist' }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'not readable by the user' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'not enabled in that org' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

          it 'fails saying the plan is invalid' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Invalid service plan. This could be due to a space-scoped broker which is offering the service plan ' \
                                    "'#{service_plan.name}' with guid '#{service_plan.guid}' in another space or that the plan " \
                                    'is not enabled in this organization. Ensure that the service plan is visible in your current space ' \
                                    "'#{space.name}' with guid '#{space.guid}'.",
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'not active' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: false) }

          it 'fails saying the plan is invalid' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => "Invalid service plan. The service plan '#{service_plan.name}' with guid '#{service_plan.guid}' " \
                                    "has been removed from the service broker's catalog. " \
                                    'It is not possible to create new service instances using this plan.',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'space-scoped plan from a different space' do
          let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: another_space) }
          let(:service_offering) { VCAP::CloudController::Service.make(service_broker:) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, active: true, public: false) }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end
      end

      describe 'the pollable job' do
        let(:request_body_additions) { { parameters: { foo: 'bar', baz: 'qux' } } }
        let(:broker_response) { { dashboard_url: 'http://dashboard.url' } }
        let(:broker_status_code) { 201 }
        let(:last_operation_status_code) { 200 }
        let(:last_operation_response) { { state: 'in progress' } }

        before do
          api_call.call(space_dev_headers)
          instance = VCAP::CloudController::ServiceInstance.last
          stub_request(:put, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
            with(query: { 'accepts_incomplete' => true }).
            to_return(status: broker_status_code, body: broker_response.to_json, headers: {})

          stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
            with(
              query: {
                operation: 'task12',
                service_id: service_plan.service.unique_id,
                plan_id: service_plan.unique_id
              }
            ).
            to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
        end

        it 'sends a provision request with the right arguments to the service broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(a_request(:put, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
            with(
              query: { accepts_incomplete: true },
              body: {
                service_id: service_plan.service.unique_id,
                plan_id: service_plan.unique_id,
                context: {
                  platform: 'cloudfoundry',
                  organization_guid: org.guid,
                  organization_name: org.name,
                  organization_annotations: { 'pre.fix/foo': 'bar' },
                  space_guid: space.guid,
                  space_name: space.name,
                  space_annotations: { 'pre.fix/baz': 'wow' },
                  instance_name: instance.name,
                  instance_annotations: { 'pre.fix/wow': 'baz' }
                },
                organization_guid: org.guid,
                space_guid: space.guid,
                parameters: {
                  foo: 'bar',
                  baz: 'qux'
                },
                maintenance_info: maintenance_info
              },
              headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
            )).to have_been_made.once
        end

        context 'when the provision completes synchronously' do
          it 'marks the service instance as created' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(instance.dashboard_url).to eq('http://dashboard.url')
            expect(instance.last_operation.type).to eq('create')
            expect(instance.last_operation.state).to eq('succeeded')
          end

          it 'completes' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          end

          context 'when the broker responds with an error' do
            let(:broker_status_code) { 400 }

            it 'marks the service instance as failed' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('failed')
              expect(instance.last_operation.description).to include('Status Code: 400 Bad Request')
            end

            it 'completes with failure' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end
          end
        end

        context 'when the provision is asynchronous' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'task12' } }

          it 'marks the job state as polling' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'calls last operation immediately' do
            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(
              a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
                )
            ).to have_been_made.once
          end

          it 'enqueues the next fetch last operation job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          context 'when last operation eventually returns `create succeeded`' do
            let(:dashboard_url) { '' }

            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

              stub_request(:get, "#{instance.service.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
                to_return(status: 200, body: { dashboard_url: }.to_json)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'sets the service instance last operation to create succeeded' do
              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('succeeded')
            end

            context 'it fetches dashboard url' do
              let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
              let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, service: service) }
              let(:dashboard_url) { 'http:/some-new-dashboard-url.com' }

              it 'sets the service instance dashboard url' do
                instance.reload

                expect(instance.dashboard_url).to eq(dashboard_url)
              end
            end
          end

          context 'when last operation eventually returns `create failed`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'failed' }.to_json, headers: {})

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to create failed' do
              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('failed')
            end
          end
        end

        describe 'volume mount and route service checks' do
          context 'when volume mount required' do
            let(:service_offering) { VCAP::CloudController::Service.make(requires: %w[volume_mount]) }
            let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

            context 'volume mount disabled' do
              before do
                TestConfig.config[:volume_services_enabled] = false
              end

              it 'warns' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::VOLUME_SERVICE_WARNING)
              end
            end

            context 'volume mount enabled' do
              before do
                TestConfig.config[:volume_services_enabled] = true
              end

              it 'does not warn' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings).to be_empty
              end
            end
          end

          context 'when route forwarding required' do
            let(:service_offering) { VCAP::CloudController::Service.make(requires: %w[route_forwarding]) }
            let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

            context 'route forwarding disabled' do
              before do
                TestConfig.config[:route_services_enabled] = false
              end

              it 'warns' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::ROUTE_SERVICE_WARNING)
              end
            end

            context 'route forwarding enabled' do
              before do
                TestConfig.config[:route_services_enabled] = true
              end

              it 'does not warn' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings).to be_empty
              end
            end
          end
        end
      end

      describe 'quotas restrictions' do
        describe 'space quotas' do
          context 'when the total services quota has been reached' do
            before do
              quota = VCAP::CloudController::SpaceQuotaDefinition.make(total_services: 1, organization: org)
              quota.add_space(space)

              VCAP::CloudController::ManagedServiceInstance.make(space:)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => "You have exceeded your space's services limit.",
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end

          context 'when the paid services quota has been reached' do
            let!(:service_plan) { VCAP::CloudController::ServicePlan.make(free: false, public: true, active: true) }

            before do
              quota = VCAP::CloudController::SpaceQuotaDefinition.make(non_basic_services_allowed: false, organization: org)
              quota.add_space(space)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => 'The service instance cannot be created because paid service plans are not allowed for your space.',
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end
        end

        describe 'organization quotas' do
          context 'when the total services quota has been reached' do
            before do
              quota = VCAP::CloudController::QuotaDefinition.make(total_services: 1)
              quota.add_organization(org)
              VCAP::CloudController::ManagedServiceInstance.make(space:)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => "You have exceeded your organization's services limit.",
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end

          context 'when the paid services quota has been reached' do
            let!(:service_plan) { VCAP::CloudController::ServicePlan.make(free: false, public: true, active: true) }

            before do
              quota = VCAP::CloudController::QuotaDefinition.make(non_basic_services_allowed: false)
              quota.add_organization(org)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => 'The service instance cannot be created because paid service plans are not allowed.',
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end
        end
      end
    end
  end

end
