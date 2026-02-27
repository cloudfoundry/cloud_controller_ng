require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances - Update' do
  include_context 'service instances setup'

  describe 'PATCH /v3/service_instances/:guid' do
    let(:api_call) { ->(user_headers) { patch "/v3/service_instances/#{guid}", request_body.to_json, user_headers } }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let(:request_body) do
      {}
    end

    context 'permissions' do
      let(:guid) { VCAP::CloudController::ServiceInstance.make(space:).guid }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_update_endpoint(success_code: 200) }
      end

      it_behaves_like 'permissions for update endpoint when organization is suspended', 200
    end

    context 'service instance does not exist' do
      let(:guid) { 'no-such-instance' }

      it 'fails saying the service instance is not found (404)' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(404)
        expect(parsed_response['errors']).to include(
          include({
                    'detail' => 'Service instance not found',
                    'title' => 'CF-ResourceNotFound',
                    'code' => 10_010
                  })
        )
      end
    end

    context 'managed service instance' do
      describe 'updates that do not require broker communication' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            guid: 'bommel',
            tags: %w[foo bar],
            space: space
          )
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy')
          VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          si
        end

        let(:guid) { service_instance.guid }

        let(:request_body) do
          {
            tags: %w[baz quz],
            metadata: {
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/to_delete': nil
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/to_delete': nil
              }
            }
          }
        end

        it 'responds synchronously' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response(
            create_managed_json(
              service_instance,
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/tail': 'fluffy'
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/fox': 'bushy'
              },
              last_operation: {
                created_at: iso8601,
                updated_at: iso8601,
                description: nil,
                state: 'succeeded',
                type: 'update'
              },
              tags: %w[baz quz]
            )
          )
        end

        it 'updates the service instance' do
          api_call.call(space_dev_headers)

          service_instance.reload
          expect(service_instance.tags).to eq(%w[baz quz])

          expect(service_instance).to have_annotations(
            { prefix: 'pre.fix', key_name: 'fox', value: 'bushy' },
            { prefix: nil, key_name: 'potato', value: 'idaho' },
            { prefix: nil, key_name: 'style', value: 'mashed' }
          )
          expect(service_instance).to have_labels(
            { prefix: 'pre.fix', key_name: 'tail', value: 'fluffy' },
            { prefix: nil, key_name: 'potato', value: 'yam' },
            { prefix: nil, key_name: 'style', value: 'baked' }
          )

          expect(service_instance.last_operation.type).to eq('update')
          expect(service_instance.last_operation.state).to eq('succeeded')
        end
      end

      describe 'updates that require broker communication' do
        # These tests verify broker request context includes org/space annotations
        let!(:org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: org.guid) }
        let!(:space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'baz', value: 'wow', space: space) }

        let(:service_offering) { VCAP::CloudController::Service.make }
        let(:original_service_plan) do
          VCAP::CloudController::ServicePlan.make(
            service: service_offering,
            plan_updateable: true,
            maintenance_info: { version: '1.1.1' }
          )
        end
        let(:new_service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let(:original_maintenance_info) { { version: '1.1.0' } }
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            guid: 'bommel',
            tags: %w[foo bar],
            space: space,
            service_plan: original_service_plan,
            maintenance_info: original_maintenance_info
          )
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy')
          VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          si
        end
        let(:guid) { service_instance.guid }
        let(:request_body) do
          {
            name: 'new-name',
            relationships: {
              service_plan: {
                data: {
                  guid: new_service_plan.guid
                }
              }
            },
            parameters: {
              foo: 'bar',
              baz: 'qux'
            },
            tags: %w[baz quz],
            metadata: {
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/to_delete': nil
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/to_delete': nil
              }
            }
          }
        end
        let(:job) { VCAP::CloudController::PollableJobModel.last }
        let(:mock_logger) { instance_double(Steno::Logger, info: nil) }

        before do
          allow(Steno).to receive(:logger).and_call_original
          allow(Steno).to receive(:logger).with('cc.api').and_return(mock_logger)
        end

        context 'when providing parameters with mixed data types' do
          let(:request_body) do
            "{\"parameters\":#{parameters_mixed_data_types_as_json_string}}"
          end
          let(:instance) { VCAP::CloudController::ServiceInstance.last }

          it 'correctly parses all data types and sends the desired JSON string to the service broker' do
            patch "/v3/service_instances/#{guid}", request_body, space_dev_headers

            expect_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:update).
              with(instance, instance.service_plan, hash_including(arbitrary_parameters: parameters_mixed_data_types_as_hash)). # correct internal representation
              and_call_original

            stub_request(:patch, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
              with(query: { 'accepts_incomplete' => true }, body: /"parameters":#{Regexp.escape(parameters_mixed_data_types_as_json_string)}/).
              to_return(status: 200, body: '{}')

            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end

        it 'responds with a pollable job' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(202)
          expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('service_instance.update')
          expect(job.resource_guid).to eq(service_instance.guid)
          expect(job.resource_type).to eq('service_instances')
        end

        it 'updates the last operation' do
          api_call.call(space_dev_headers)

          expect(service_instance.last_operation.type).to eq('update')
          expect(service_instance.last_operation.state).to eq('in progress')
        end

        it 'does not immediately update the service instance' do
          api_call.call(space_dev_headers)

          service_instance.reload
          expect(service_instance.reload.tags).to eq(%w[foo bar])

          expect(service_instance).to have_annotations(
            { prefix: 'pre.fix', key_name: 'to_delete', value: 'value' },
            { prefix: 'pre.fix', key_name: 'fox', value: 'bushy' }
          )
          expect(service_instance).to have_labels(
            { prefix: 'pre.fix', key_name: 'to_delete', value: 'value' },
            { prefix: 'pre.fix', key_name: 'tail', value: 'fluffy' }
          )
        end

        describe 'logging of updates' do
          it 'logs info including the change of service plans' do
            api_call.call(space_dev_headers)

            expect(mock_logger).to have_received(:info).with(
              "Updating managed service instance with name '#{service_instance.name}' " \
              "changing plan from '#{original_service_plan.name}' to '#{new_service_plan.name}' " \
              "from service offering '#{service_offering.name}' " \
              "provided by broker '#{original_service_plan.service.service_broker.name}'."
            )
          end

          context 'when service plan does not change' do
            let(:request_body) do
              {
                parameters: {
                  foo: 'bar',
                  baz: 'qux'
                }
              }
            end

            it 'logs info accordingly' do
              api_call.call(space_dev_headers)

              expect(mock_logger).to have_received(:info).with(
                "Updating managed service instance with name '#{service_instance.name}' " \
                "using service plan '#{original_service_plan.name}' " \
                "from service offering '#{service_offering.name}' " \
                "provided by broker '#{original_service_plan.service.service_broker.name}'."
              )
            end
          end
        end

        describe 'the pollable job' do
          let(:broker_response) { { dashboard_url: 'http://new-dashboard.url' } }
          let(:broker_status_code) { 200 }

          before do
            api_call.call(space_dev_headers)

            instance = VCAP::CloudController::ServiceInstance.last

            stub_request(:patch, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
              with(query: { 'accepts_incomplete' => true }).
              to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
          end

          it 'sends a UPDATE request with the right arguments to the service broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            expect(
              a_request(:patch, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}").
                with(
                  query: { accepts_incomplete: true },
                  body: {
                    service_id: new_service_plan.service.unique_id,
                    plan_id: new_service_plan.unique_id,
                    previous_values: {
                      plan_id: original_service_plan.unique_id,
                      service_id: original_service_plan.service.unique_id,
                      organization_id: org.guid,
                      space_id: space.guid,
                      maintenance_info: { version: '1.1.0' }
                    },
                    context: {
                      platform: 'cloudfoundry',
                      organization_guid: org.guid,
                      organization_name: org.name,
                      organization_annotations: { 'pre.fix/foo': 'bar' },
                      space_guid: space.guid,
                      space_name: space.name,
                      space_annotations: { 'pre.fix/baz': 'wow' },
                      instance_name: 'new-name'
                    },
                    parameters: {
                      foo: 'bar',
                      baz: 'qux'
                    }
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
                )
            ).to have_been_made.once
          end

          context 'when the update completes synchronously' do
            it 'marks the service instance as updated' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              service_instance.reload
              expect(service_instance.dashboard_url).to eq('http://new-dashboard.url')
              expect(service_instance.last_operation.type).to eq('update')
              expect(service_instance.last_operation.state).to eq('succeeded')
              expect(service_instance.maintenance_info).to eq(new_service_plan.maintenance_info)
            end

            it 'marks the job as complete' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            context 'when the broker responds with an error' do
              let(:broker_status_code) { 400 }

              it 'marks the service instance as failed' do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to include('Status Code: 400 Bad Request')
              end

              it 'marks the job as failed' do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              end
            end
          end

          context 'when the update is asynchronous' do
            let(:broker_status_code) { 202 }
            let(:broker_response) { { operation: 'task12' } }
            let(:last_operation_status_code) { 200 }
            let(:last_operation_response) { { state: 'in progress' } }
            let(:dashboard_url) {}

            before do
              stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_instance.service_plan.service.unique_id,
                    plan_id: service_instance.service_plan.unique_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})

              stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}").
                to_return(status: 200, body: { dashboard_url: }.to_json)
            end

            it 'marks the job state as polling' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
            end

            it 'calls last operation immediately' do
              encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(
                a_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id
                    },
                    headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
                  )
              ).to have_been_made.once
            end

            it 'enqueues the next fetch last operation job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)
            end

            context 'when last operation eventually returns `update succeeded`' do
              let(:last_operation_status_code) { 200 }
              let(:last_operation_response) { { state: 'in progress' } }

              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id
                    }
                  ).
                  to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                  to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

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
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('succeeded')
              end

              context 'it fetches dashboard url' do
                let(:service_offering) { VCAP::CloudController::Service.make(instances_retrievable: true) }
                let(:dashboard_url) { 'http:/some-new-dashboard-url.com' }

                it 'sets the service instance dashboard url' do
                  service_instance.reload
                  expect(service_instance.dashboard_url).to eq(dashboard_url)
                end
              end
            end

            context 'when last operation eventually returns `update failed`' do
              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id
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

              it 'sets the service instance last operation to update failed' do
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
              end
            end

            context 'when last operation eventually returns error 400' do
              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id
                    }
                  ).
                  to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                  to_return(status: 400, body: {}.to_json, headers: {})

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

              it 'sets the service instance last operation to update failed' do
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
              end

              it 'does not update the instance' do
                #  TODO maybe look in the client to add this test and make sure what it returns? so we can test at a unit level in the job as well
                service_instance.reload
                expect(service_instance.reload.tags).to eq(%w[foo bar])
                expect(service_instance.service_plan).to eq(original_service_plan)
                expect(service_instance).to have_annotations(
                  { prefix: 'pre.fix', key_name: 'to_delete', value: 'value' },
                  { prefix: 'pre.fix', key_name: 'fox', value: 'bushy' }
                )
                expect(service_instance).to have_labels(
                  { prefix: 'pre.fix', key_name: 'to_delete', value: 'value' },
                  { prefix: 'pre.fix', key_name: 'tail', value: 'fluffy' }
                )
              end

              context 'when changing maintenance_info' do
                let(:request_body) do
                  {
                    maintenance_info: { version: '1.1.1' }
                  }
                end

                it 'does not update the instance' do
                  service_instance.reload
                  expect(service_instance.maintenance_info.symbolize_keys).to eq(original_maintenance_info)
                end
              end
            end
          end

          context 'changing maintenance_info alongside other parameters' do
            let(:new_maintenance_info) { { version: '1.1.1' } }
            let(:request_body) do
              {
                name: 'new-name',
                maintenance_info: new_maintenance_info,
                tags: %w[baz quz]
              }
            end

            it 'modifies the instance' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              service_instance.reload
              expect(service_instance.maintenance_info.symbolize_keys).to eq(new_maintenance_info)
              expect(service_instance.last_operation.type).to eq('update')
              expect(service_instance.last_operation.state).to eq('succeeded')
              expect(service_instance.name).to eq('new-name')
              expect(service_instance.tags).to include('baz', 'quz')
            end
          end
        end

        context 'database disconnect error during creation of pollable job' do
          before do
            allow(VCAP::CloudController::PollableJobModel).to receive(:create).and_raise(Sequel::DatabaseDisconnectError)
          end

          it 'sets the last operation to failed' do
            api_call.call(space_dev_headers)

            service_instance.reload
            expect(service_instance.last_operation.type).to eq('update')
            expect(service_instance.last_operation.state).to eq('failed')
          end
        end
      end

      describe 'no changes requested' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w[foo bar],
            space: space
          )
          si
        end

        let(:guid) { service_instance.guid }

        it 'updates the instance synchronously' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response(
            create_managed_json(
              service_instance,
              last_operation: {
                created_at: iso8601,
                updated_at: iso8601,
                description: nil,
                state: 'succeeded',
                type: 'update'
              },
              tags: %w[foo bar]
            )
          )
        end
      end

      describe 'maintenance_info checks' do
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            space:,
            service_plan:
          )
        end
        let(:guid) { service_instance.guid }

        context 'changing maintenance_info when the plan does not support it' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, service: service_offering) }
          let(:service_plan_guid) { service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '3.1.0'
              }
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => 'The service broker does not support upgrades for service instances created from this plan.',
                  'code' => 10_008
                }
              )
            )
          end
        end

        context 'maintenance_info conflict' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) do
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.1.0' }
            )
          end
          let(:service_plan_guid) { service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '2.2.0'
              }
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => include('maintenance_info.version requested is invalid'),
                  'code' => 10_008
                }
              )
            )
          end
        end

        context 'changing maintenance_info alongside plan' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) do
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.2.0' }
            )
          end

          let(:new_service_plan) do
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.1.0' }
            )
          end

          let(:new_service_plan_guid) { new_service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '2.2.0'
              },
              relationships: {
                service_plan: {
                  data: {
                    guid: new_service_plan_guid
                  }
                }
              }
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => include('maintenance_info should not be changed when switching to different plan.'),
                  'code' => 10_008
                }
              )
            )
          end
        end
      end

      describe 'service plan checks' do
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w[foo bar],
            space: space
          )
        end
        let(:guid) { service_instance.guid }

        let(:request_body) do
          {
            relationships: {
              service_plan: {
                data: {
                  guid: service_plan_guid
                }
              }
            }
          }
        end

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
          let(:service_plan_guid) { service_plan.guid }

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
          let(:service_plan_guid) { service_plan.guid }

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

        context 'not available' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: false) }
          let(:service_plan_guid) { service_plan.guid }

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
          let(:service_plan_guid) { service_plan.guid }

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

        context 'relates to a different service offering' do
          let(:service_plan_guid) { VCAP::CloudController::ServicePlan.make.guid }

          it 'fails saying the plan relates to a different service offering' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(400)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'service plan relates to a different service offering',
                        'title' => 'CF-InvalidRelation',
                        'code' => 1002
                      })
            )
          end
        end
      end

      describe 'name checks' do
        context 'name is already used in this space' do
          let(:guid) { service_instance.guid }
          let!(:service_instance) do
            VCAP::CloudController::ManagedServiceInstance.make(
              tags: %w[foo bar],
              space: space
            )
          end

          let!(:name) { 'test' }
          let!(:other_si) { VCAP::CloudController::ServiceInstance.make(name:, space:) }
          let(:request_body) { { name: } }

          it 'fails' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => "The service instance name is taken: #{name}",
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end
      end

      describe 'invalid request' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w[foo bar],
            space: space
          )
          si
        end

        let(:guid) { service_instance.guid }
        let(:request_body) do
          {
            relationships: {
              space: {
                data: {
                  guid: 'some-space'
                }
              }
            }
          }
        end

        it 'fails' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => include("Relationships Unknown field(s): 'space'"),
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end
      end

      describe 'when the SI plan is no longer active' do
        let(:version) { { version: '2.0.0' } }
        let(:service_offering) { VCAP::CloudController::Service.make }
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(
            public: true,
            active: false,
            maintenance_info: version,
            service: service_offering
          )
        end
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:)
        end
        let(:guid) { service_instance.guid }

        context 'and the request is updating parameters' do
          let(:request_body) { { parameters: { foo: 'bar', baz: 'qux' } } }

          it 'fails with a plan inaccessible message' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Cannot update parameters of a service instance that belongs to inaccessible plan',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'and the request is updating maintenance_info' do
          let(:request_body) { { maintenance_info: { version: '2.0.0' } } }

          it 'fails with a plan inaccessible message' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                        'detail' => 'Cannot update maintenance_info of a service instance that belongs to inaccessible plan',
                        'title' => 'CF-UnprocessableEntity',
                        'code' => 10_008
                      })
            )
          end
        end

        context 'and the request is updating the SI name' do
          let(:request_body) { { name: 'new-name' } }

          context 'and the service offering allows contextual updates' do
            let(:service_offering) { VCAP::CloudController::Service.make(allow_context_updates: true) }

            it 'fails with a plan inaccessible message' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                          'detail' => 'Cannot update name of a service instance that belongs to inaccessible plan',
                          'title' => 'CF-UnprocessableEntity',
                          'code' => 10_008
                        })
              )
            end
          end

          context 'but the service offering does not allow contextual updates' do
            let(:service_offering) { VCAP::CloudController::Service.make(allow_context_updates: false) }

            it 'succeeds' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(200)
            end
          end
        end
      end
    end

    context 'user-provided service instance' do
      let!(:service_instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(
          guid: 'bommel',
          space: space,
          name: 'foo',
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          syslog_drain_url: 'https://foo.com',
          route_service_url: 'https://bar.com',
          tags: %w[accounting mongodb]
        )
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy')
        VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
        VCAP::CloudController::ServiceInstanceLabelModel.make(service_instance: si, key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        si
      end

      let(:guid) { service_instance.guid }
      let(:new_name) { 'my_service_instance' }

      let(:request_body) do
        {
          name: new_name,
          credentials: {
            used_in: 'bindings',
            foo: 'bar'
          },
          syslog_drain_url: 'https://foo2.com',
          route_service_url: 'https://bar2.com',
          tags: %w[accounting couchbase nosql],
          metadata: {
            labels: {
              foo: 'bar',
              'pre.fix/to_delete': nil
            },
            annotations: {
              alpha: 'beta',
              'pre.fix/to_delete': nil
            }
          }
        }
      end

      it 'allows updates' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(200)

        expect(parsed_response).to match_json_response(
          create_user_provided_json(
            service_instance.reload,
            labels: {
              foo: 'bar',
              'pre.fix/tail': 'fluffy'
            },
            annotations: {
              alpha: 'beta',
              'pre.fix/fox': 'bushy'
            },
            last_operation: {
              type: 'update',
              state: 'succeeded',
              description: 'Operation succeeded',
              created_at: iso8601,
              updated_at: iso8601
            }
          )
        )
      end

      it 'updates the a service instance in the database' do
        api_call.call(space_dev_headers)

        instance = VCAP::CloudController::ServiceInstance.last

        expect(instance.name).to eq(new_name)
        expect(instance.syslog_drain_url).to eq('https://foo2.com')
        expect(instance.route_service_url).to eq('https://bar2.com')
        expect(instance.tags).to contain_exactly('accounting', 'couchbase', 'nosql')
        expect(instance.space).to eq(space)
        expect(instance.last_operation.type).to eq('update')
        expect(instance.last_operation.state).to eq('succeeded')
        expect(instance).to have_labels({ prefix: 'pre.fix', key_name: 'tail', value: 'fluffy' }, { prefix: nil, key_name: 'foo', value: 'bar' })
        expect(instance).to have_annotations({ prefix: 'pre.fix', key_name: 'fox', value: 'bushy' }, { prefix: nil, key_name: 'alpha', value: 'beta' })
      end

      context 'when the request is invalid' do
        let(:request_body) do
          {
            guid: Sham.guid
          }
        end

        it 'is rejected' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => include("Unknown field(s): 'guid'"),
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end
      end

      context 'when the name is already taken' do
        let!(:duplicate_name) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, name: new_name) }

        let(:request_body) do
          {
            name: new_name
          }
        end

        it 'is rejected' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
                      'detail' => "The service instance name is taken: #{new_name}.",
                      'title' => 'CF-UnprocessableEntity',
                      'code' => 10_008
                    })
          )
        end
      end
    end

    context 'when an operation is in progress' do
      let(:service_instance) do
        si = VCAP::CloudController::ManagedServiceInstance.make(
          space:
        )
        si
      end
      let(:guid) { service_instance.guid }
      let(:request_body) do
        {
          metadata: {
            labels: { unit: 'metre', distance: '1003' },
            annotations: { location: 'london' }
          }
        }
      end

      context 'and it is a create operation' do
        before do
          service_instance.save_with_new_operation({}, { type: 'create', state: 'in progress', description: 'almost there, I promise' })
        end

        context 'and the update contains metadata only' do
          it 'updates the metadata' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(200)
            expect(parsed_response.dig('metadata', 'labels')).to eq({ 'unit' => 'metre', 'distance' => '1003' })
            expect(parsed_response.dig('metadata', 'annotations')).to eq({ 'location' => 'london' })
          end

          it 'does not update the service instance last operation' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(200)
            expect(parsed_response['last_operation']).to include({
                                                                   'type' => 'create',
                                                                   'state' => 'in progress',
                                                                   'description' => 'almost there, I promise'
                                                                 })
          end
        end

        context 'and the update contains more than just metadata' do
          it 'returns an error' do
            request_body[:name] = 'new-name'
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(409)
            response = parsed_response['errors'].first
            expect(response).to include('title' => 'CF-AsyncServiceInstanceOperationInProgress')
            expect(response).to include('detail' => include("An operation for service instance #{service_instance.name} is in progress"))
          end
        end
      end

      context 'and it is an update operation' do
        before do
          service_instance.save_with_new_operation({}, { type: 'update', state: 'in progress', description: 'almost there, I promise' })
        end

        context 'and the update contains metadata only' do
          it 'updates the metadata' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(200)
            expect(parsed_response.dig('metadata', 'labels')).to eq({ 'unit' => 'metre', 'distance' => '1003' })
            expect(parsed_response.dig('metadata', 'annotations')).to eq({ 'location' => 'london' })
          end

          it 'does not update the service instance last operation' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(200)
            expect(parsed_response['last_operation']).to include({
                                                                   'type' => 'update',
                                                                   'state' => 'in progress',
                                                                   'description' => 'almost there, I promise'
                                                                 })
          end
        end

        context 'and the update contains more than just metadata' do
          it 'returns an error' do
            request_body[:name] = 'new-name'
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(409)
            response = parsed_response['errors'].first
            expect(response).to include('title' => 'CF-AsyncServiceInstanceOperationInProgress')
            expect(response).to include('detail' => include("An operation for service instance #{service_instance.name} is in progress"))
          end
        end
      end

      context 'and it is a delete operation' do
        before do
          service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress', description: 'almost there, I promise' })
        end

        context 'and the update contains metadata only' do
          it 'returns an error' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(409)
            response = parsed_response['errors'].first
            expect(response).to include('title' => 'CF-AsyncServiceInstanceOperationInProgress')
            expect(response).to include('detail' => include("An operation for service instance #{service_instance.name} is in progress"))
          end
        end

        context 'and the update contains more than just metadata' do
          it 'returns an error' do
            request_body[:name] = 'new-name'
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(409)
            response = parsed_response['errors'].first
            expect(response).to include('title' => 'CF-AsyncServiceInstanceOperationInProgress')
            expect(response).to include('detail' => include("An operation for service instance #{service_instance.name} is in progress"))
          end
        end
      end
    end
  end
end
