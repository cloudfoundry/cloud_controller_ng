require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances - Delete' do
  include_context 'service instances setup'

  describe 'DELETE /v3/service_instances/:guid' do
    let(:query_params) { '' }
    let(:api_call) { ->(user_headers) { delete "/v3/service_instances/#{instance.guid}?#{query_params}", '{}', user_headers } }

    context 'permissions' do
      let!(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }
      let(:db_check) do
        lambda {
          expect(VCAP::CloudController::ServiceInstance.all).to be_empty
        }
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_delete_endpoint }
      end

      it_behaves_like 'permissions for delete endpoint when organization is suspended', 204
    end

    context 'user provided service instances' do
      let!(:instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: 'https://banana.example.com/')
        si.service_instance_operation = VCAP::CloudController::ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
        si
      end
      let(:instance_labels) { VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: instance) }
      let(:instance_annotations) { VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: instance) }

      before do
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'banana', service_instance: instance)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'spice', value: 'cinnamon', service_instance: instance)
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'contact', value: 'marie', service_instance: instance)
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'email', value: 'some@example.com', service_instance: instance)
      end

      it 'deletes the instance and removes any labels or annotations' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(204)

        get "/v3/service_instances/#{instance.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)
        expect(VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: instance).all).to be_empty
        expect(VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: instance).all).to be_empty
      end

      it 'deletes any related bindings' do
        VCAP::CloudController::RouteBinding.make(service_instance: instance)
        VCAP::CloudController::ServiceBinding.make(service_instance: instance)

        api_call.call(admin_headers)
        expect(last_response).to have_status_code(204)

        expect(VCAP::CloudController::ServiceInstance.all).to be_empty
        expect(VCAP::CloudController::RouteBinding.all).to be_empty
        expect(VCAP::CloudController::ServiceBinding.all).to be_empty
      end

      context 'with purge' do
        let(:query_params) { 'purge=true' }

        before do
          @binding = VCAP::CloudController::ServiceBinding.make(service_instance: instance)
          @route = VCAP::CloudController::RouteBinding.make(service_instance: instance)
        end

        it 'deletes the instance and the related resources' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(204)

          expect { instance.reload }.to raise_error Sequel::NoExistingObject
          expect { @binding.reload }.to raise_error Sequel::NoExistingObject
          expect { @route.reload }.to raise_error Sequel::NoExistingObject
          expect(instance_labels.count).to eq(0)
          expect(instance_annotations.count).to eq(0)
        end
      end
    end

    context 'managed service instance' do
      let!(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
      let(:broker_status_code) { 200 }
      let(:broker_response) { {} }
      let!(:stub_delete) do
        stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
          with(query: {
                 'accepts_incomplete' => true,
                 'service_id' => instance.service.broker_provided_id,
                 'plan_id' => instance.service_plan.broker_provided_id
               }).
          to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
      end
      let(:mock_logger) { instance_double(Steno::Logger, info: nil) }

      before do
        allow(Steno).to receive(:logger).and_call_original
        allow(Steno).to receive(:logger).with('cc.api').and_return(mock_logger)
      end

      it 'responds with job resource' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(202)

        job = VCAP::CloudController::PollableJobModel.last
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_instance.delete')
        expect(job.resource_guid).to eq(instance.guid)
        expect(job.resource_type).to eq('service_instance')
      end

      it 'logs the correct names when deleting a managed service instance' do
        api_call.call(admin_headers)

        expect(mock_logger).to have_received(:info).with(
          "Deleting managed service instance with name '#{instance.name}' " \
          "using service plan '#{instance.service_plan.name}' " \
          "from service offering '#{instance.service_plan.service.name}' " \
          "provided by broker '#{instance.service_plan.service.service_broker.name}'."
        )
      end

      describe 'the pollable job' do
        it 'sends a delete request with the right arguments to the service broker' do
          api_call.call(headers_for(user, scopes: %w[cloud_controller.admin]))

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(
            a_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
              with(
                query: {
                  accepts_incomplete: true,
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                },
                headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
              )
          ).to have_been_made.once
        end

        context 'when the service broker responds synchronously' do
          context 'with success' do
            it 'removes the service instance' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end

            it 'completes the job' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              job = VCAP::CloudController::PollableJobModel.last
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'with an error' do
            let(:broker_status_code) { 404 }

            it 'marks the service instance as delete failed' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)
              instance.reload

              expect(instance.last_operation).not_to be_nil
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
            end

            it 'completes with failure' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              job = VCAP::CloudController::PollableJobModel.last
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end
          end
        end

        context 'when the service broker responds asynchronously' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'some delete operation' } }
          let(:last_operation_response) { { state: 'in progress', description: 'deleting si' } }
          let(:last_operation_status_code) { 200 }
          let(:job) { VCAP::CloudController::PollableJobModel.last }

          before do
            stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
              with(
                query: {
                  operation: 'some delete operation',
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                }
              ).
              to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
          end

          it 'marks the job state as polling' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'calls last operation immediately' do
            api_call.call(headers_for(user, scopes: %w[cloud_controller.admin]))
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            expect(
              a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
                )
            ).to have_been_made.once
          end

          it 'enqueues the next fetch last operation job' do
            api_call.call(admin_headers)

            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          it 'sets the service instance last operation to delete in progress' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            instance.reload

            expect(instance.last_operation).not_to be_nil
            expect(instance.last_operation.type).to eq('delete')
            expect(instance.last_operation.state).to eq('in progress')
          end

          context 'when last operation eventually returns `delete succeeded`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

              api_call.call(admin_headers)

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

            it 'removes the service instance last from the db' do
              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end
          end

          context 'when last operation eventually returns `delete failed`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(3).then.
                to_return(status: 200, body: { state: 'failed', description: 'oh no failed' }.to_json, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              (1..2).each do |attempt|
                Timecop.freeze(Time.now + attempt.hour) do
                  execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)
                end
              end
              Timecop.freeze(Time.now + 3.hours) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to delete failed' do
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
              expect(instance.last_operation.description).to eq('oh no failed')
            end
          end

          context 'when last operation eventually returns 410 Gone' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 410, headers: {})

              api_call.call(admin_headers)

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

            it 'removes the service instance last from the db' do
              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end
          end

          context 'when last operation eventually returns 400 Bad Request' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 400, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)
              end
            end

            it 'fails the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to delete failed' do
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
            end
          end

          context 'when last operation returns with an unknown status code' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }
                ).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 404, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'continues to poll' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
            end
          end
        end

        context 'when the service instance is shared' do
          let!(:shared_space) do
            VCAP::CloudController::Space.make.tap do |s|
              instance.add_shared_space(s)
            end
          end

          it 'removes the service instance' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(VCAP::CloudController::ServiceInstance.all).to be_empty
          end

          context 'when there is a binding in the shared space' do
            let!(:application) { VCAP::CloudController::AppModel.make(space: shared_space) }
            let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: application) }

            before do
              stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{service_binding.guid}").
                with(query: {
                       'accepts_incomplete' => true,
                       'service_id' => instance.service.broker_provided_id,
                       'plan_id' => instance.service_plan.broker_provided_id
                     }).
                to_return(status: 202, body: '{}', headers: {})
            end

            it 'fails when the unbind is async' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)

              lo = instance.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('failed')
              expect(lo.description).to eq("An operation for the service binding between app #{application.name} and service instance #{instance.name} is in progress.")

              expect(
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{service_binding.guid}").
                  with(query: {
                         'accepts_incomplete' => true,
                         service_id: instance.service.broker_provided_id,
                         plan_id: instance.service_plan.broker_provided_id
                       })
              ).to have_been_made.once
            end
          end
        end

        context 'when there are bindings' do
          let(:service_offering) { VCAP::CloudController::Service.make(requires: %w[route_forwarding]) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
          let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:) }
          let!(:route_binding) { VCAP::CloudController::RouteBinding.make(service_instance: instance) }
          let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance) }
          let!(:service_key) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }

          context 'and the broker responds synchronously to the bindings being deleted' do
            before do
              [route_binding, service_binding, service_key].each do |binding|
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                  with(query: {
                         'accepts_incomplete' => true,
                         'service_id' => instance.service.broker_provided_id,
                         'plan_id' => instance.service_plan.broker_provided_id
                       }).
                  to_return(status: 200, body: '{}', headers: {})
              end
            end

            it 'removes the service instance' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::ServiceInstance.all).to be_empty
              expect(VCAP::CloudController::RouteBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceKey.all).to be_empty

              [route_binding, service_binding, service_key].each do |binding|
                expect(
                  a_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                    with(query: {
                           accepts_incomplete: true,
                           service_id: instance.service.broker_provided_id,
                           plan_id: instance.service_plan.broker_provided_id
                         })
                ).to have_been_made.once
              end
            end
          end

          context 'and the broker responds asynchronously to the bindings being deleted' do
            before do
              [route_binding, service_binding, service_key].each do |binding|
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                  with(query: {
                         'accepts_incomplete' => true,
                         'service_id' => instance.service.broker_provided_id,
                         'plan_id' => instance.service_plan.broker_provided_id
                       }).
                  to_return(status: 202, body: '{}', headers: {})

                stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}/last_operation").
                  with(query: {
                         'service_id' => instance.service.broker_provided_id,
                         'plan_id' => instance.service_plan.broker_provided_id
                       }).
                  to_return(status: 200, body: '{"state":"succeeded"}', headers: {})
              end
            end

            it 'fails and starts the delete operation on the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)

              lo = VCAP::CloudController::ServiceInstance.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('failed')
              expect(lo.description).to eq("An operation for a service binding of service instance #{instance.name} is in progress.")

              lo = VCAP::CloudController::RouteBinding.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')

              lo = VCAP::CloudController::ServiceBinding.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')

              lo = VCAP::CloudController::ServiceKey.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')
            end

            it 'continues to poll the last operation for the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 3, expected_failures: 1)

              [route_binding, service_binding, service_key].each do |binding|
                expect(
                  stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}/last_operation").
                    with(query: {
                           service_id: instance.service.broker_provided_id,
                           plan_id: instance.service_plan.broker_provided_id
                         })
                ).to have_been_made.once
              end
            end

            it 'eventually removes the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 3, expected_failures: 1)

              expect(VCAP::CloudController::RouteBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceKey.all).to be_empty
            end
          end
        end
      end

      context 'when purge is true' do
        let(:query_params) { 'purge=true' }
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:) }

        context 'when broker is space scoped' do
          let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space:) }
          let(:service_offering) { VCAP::CloudController::Service.make(requires: %w[route_forwarding], service_broker: service_broker) }

          context 'as developer' do
            let(:space_dev_headers) do
              org.add_user(user)
              space.add_developer(user)
              headers_for(user)
            end

            it 'deletes the service instance' do
              api_call.call(space_dev_headers)

              expect(last_response).to have_status_code(204)
              expect { instance.reload }.to raise_error Sequel::NoExistingObject
            end
          end

          context 'as admin' do
            it 'deletes the service instance' do
              api_call.call(admin_headers)

              expect(last_response).to have_status_code(204)
              expect { instance.reload }.to raise_error Sequel::NoExistingObject
            end
          end
        end

        context 'when broker is global' do
          let(:service_offering) { VCAP::CloudController::Service.make(requires: %w[route_forwarding]) }

          before do
            @binding = VCAP::CloudController::ServiceBinding.make(service_instance: instance)
            @key = VCAP::CloudController::ServiceKey.make(service_instance: instance)
            @route = VCAP::CloudController::RouteBinding.make(service_instance: instance)
          end

          context 'as developer' do
            let(:space_dev_headers) do
              org.add_user(user)
              space.add_developer(user)
              headers_for(user)
            end

            it 'responds with 403' do
              api_call.call(space_dev_headers)

              expect(last_response).to have_status_code(403)
            end
          end

          context 'as admin' do
            before do
              api_call.call(admin_headers)
            end

            it 'removes all associations' do
              expect { @binding.reload }.to raise_error Sequel::NoExistingObject
              expect { @key.reload }.to raise_error Sequel::NoExistingObject
              expect { @route.reload }.to raise_error Sequel::NoExistingObject
            end

            it 'deletes the service instance' do
              expect { instance.reload }.to raise_error Sequel::NoExistingObject
            end

            it 'responds with 204' do
              expect(last_response).to have_status_code(204)
            end
          end
        end
      end

      context 'when delete is already in progress' do
        before do
          instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
        end

        it 'responds with 422' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
                                                                 'detail' => include('There is an operation in progress for the service instance.'),
                                                                 'title' => 'CF-UnprocessableEntity',
                                                                 'code' => 10_008
                                                               }))
        end
      end

      context 'when the service instance creation request has not been responded to be the broker' do
        before do
          instance.save_with_new_operation({}, { type: 'create', state: 'initial' })
        end

        it 'responds with 422' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
                                                                 'detail' => include('There is an operation in progress for the service instance.'),
                                                                 'title' => 'CF-UnprocessableEntity',
                                                                 'code' => 10_008
                                                               }))
        end
      end

      context 'when the creation is still in progress' do
        before do
          instance.save_with_new_operation({}, {
                                             type: 'create',
                                             state: 'in progress',
                                             broker_provided_operation: 'some create operation'
                                           })
        end

        context 'and the broker confirms the deletion' do
          it 'deletes the service instance' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
          end
        end

        context 'and the broker accepts the delete' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'some delete operation' } }
          let(:last_operation_response) { { state: 'in progress', description: 'deleting si' } }
          let(:last_operation_status_code) { 200 }

          before do
            stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
              with(
                query: {
                  operation: 'some delete operation',
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                }
              ).
              to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
          end

          it 'triggers the delete process' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            instance.reload

            expect(instance.last_operation).not_to be_nil
            expect(instance.last_operation.type).to eq('delete')
            expect(instance.last_operation.state).to eq('in progress')
            expect(instance.last_operation.broker_provided_operation).to eq('some delete operation')
          end
        end

        context 'but the broker rejects the delete' do
          let(:broker_status_code) { 422 }
          let(:broker_response) { { error: 'ConcurrencyError', description: 'Cannot delete right now' } }

          it 'responds with an error' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            job = VCAP::CloudController::PollableJobModel.last
            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)

            expect(job.cf_api_error).not_to be_nil
            api_error = YAML.safe_load(job.cf_api_error)['errors'].first
            expect(api_error['title']).to eql('CF-AsyncServiceInstanceOperationInProgress')
            expect(api_error['detail']).to eql("An operation for service instance #{instance.name} is in progress.")
          end

          it 'does not change the operation in progress' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            instance.reload

            expect("#{instance.last_operation.type} #{instance.last_operation.state}").to eq('create in progress')
            expect(instance.last_operation.broker_provided_operation).to eq('some create operation')
          end
        end
      end
    end

    context 'when the service instance does not exist' do
      let(:instance) { Struct.new(:guid).new('some-fake-guid') }

      it 'returns a 404' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(404)
      end
    end
  end

end
