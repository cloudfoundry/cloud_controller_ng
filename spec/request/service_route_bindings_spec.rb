require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service route bindings' do
  describe 'POST /v3/service_route_bindings' do
    let(:api_call) { ->(user_headers) { post '/v3/service_route_bindings', request.to_json, user_headers } }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:request) do
      {
        relationships: {
          service_instance: {
            data: {
              guid: service_instance.guid
            }
          },
          route: {
            data: {
              guid: route.guid
            }
          }
        }
      }.deep_merge(request_extra)
    end
    let(:request_extra) { {} }

    RSpec.shared_examples 'create route binding' do
      context 'invalid body' do
        let(:request) do
          { foo: 'bar' }
        end

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "Unknown field(s): 'foo', Relationships 'relationships' is not an object",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'route binding disabled by platform' do
        before do
          TestConfig.config[:route_services_enabled] = false
        end

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'Support for route services is disabled',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'cannot read route' do
        let(:route) { VCAP::CloudController::Route.make }

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The route could not be found: #{route.guid}",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'route is internal' do
        let(:domain) { VCAP::CloudController::SharedDomain.make(internal: true, name: 'my.domain.com') }
        let(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }

        it 'fails with a 422 unprocessable' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'Route services cannot be bound to internal routes',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'route and service instance in different spaces' do
        let(:route) { VCAP::CloudController::Route.make }

        it 'fails with a 422 unprocessable' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'The service instance and the route are in different spaces',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'route is bound to a different service instance' do
        let(:other_service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

        before do
          VCAP::CloudController::RouteBinding.make(
            route: route,
            service_instance: other_service_instance,
          )
        end

        it 'fails with a 422 unprocessable' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'A route may only be bound to a single service instance',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end

      context 'binding already exists' do
        before do
          VCAP::CloudController::RouteBinding.make(
            route: route,
            service_instance: service_instance,
          )
        end

        it 'fails with a specific error' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)

          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'The route and service instance are already bound.',
              'title' => 'CF-ServiceInstanceAlreadyBoundToSameRoute',
              'code' => 130008,
            })
          )
        end
      end

      context 'service instance is bound to a different route' do
        let(:other_route) { VCAP::CloudController::Route.make(space: space) }

        before do
          VCAP::CloudController::RouteBinding.make(
            route: other_route,
            service_instance: service_instance,
          )
        end

        it 'succeeds' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(201).or have_status_code(202)
        end
      end
    end

    context 'managed service instance' do
      let(:offering) { VCAP::CloudController::Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
      let(:plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: plan) }
      let(:binding) { VCAP::CloudController::RouteBinding.last }
      let(:job) { VCAP::CloudController::PollableJobModel.last }

      it_behaves_like 'create route binding'

      it 'creates a route binding precursor in the database' do
        api_call.call(space_dev_headers)

        expect(binding.service_instance).to eq(service_instance)
        expect(binding.route).to eq(route)
        expect(binding.route_service_url).to be_nil
      end

      it 'responds with a job resource' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(202)
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_route_bindings.create')
        expect(job.resource_guid).to eq(binding.guid)
        expect(job.resource_type).to eq('service_route_binding')
      end

      describe 'the pollable job' do
        let(:broker_base_url) { service_instance.service_broker.broker_url }
        let(:broker_bind_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }
        let(:route_service_url) { 'https://route_service_url.com' }
        let(:broker_status_code) { 201 }
        let(:broker_response) { { route_service_url: route_service_url } }
        let(:client_body) do
          {
            context: {
              platform: 'cloudfoundry',
              organization_guid: org.guid,
              organization_name: org.name,
              space_guid: space.guid,
              space_name: space.name,
            },
            service_id: service_instance.service_plan.service.unique_id,
            plan_id: service_instance.service_plan.unique_id,
            bind_resource: {
              route: route.uri,
            },
          }
        end

        before do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(202)

          stub_request(:put, broker_bind_url).
            with(query: { accepts_incomplete: true }).
            to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
        end

        it 'sends a bind request with the right arguments to the service broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(
            a_request(:put, broker_bind_url).
              with(
                query: { accepts_incomplete: true },
                body: client_body,
              )
          ).to have_been_made.once
        end

        context 'parameters are specified' do
          let(:request_extra) do
            {
              parameters: { foo: 'bar' }
            }
          end

          it 'sends the parameters to the broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:put, broker_bind_url).
                with(
                  query: { accepts_incomplete: true },
                  body: client_body.deep_merge(request_extra)
                )
            ).to have_been_made.once
          end
        end

        context 'when the bind completes synchronously' do
          it 'updates the the binding' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            binding.reload
            expect(binding.route_service_url).to eq(route_service_url)
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('succeeded')
          end

          it 'completes the job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
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
              with(query: {
                operation: operation,
                service_id: service_instance.service_plan.service.unique_id,
                plan_id: service_instance.service_plan.unique_id,
              }).
              to_return(status: last_operation_status_code, body: last_operation_body.to_json, headers: {})
          end

          it 'polls the last operation endpoint' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:get, broker_binding_last_operation_url).
                with(query: {
                  operation: operation,
                  service_id: service_instance.service_plan.service.unique_id,
                  plan_id: service_instance.service_plan.unique_id,
                })
            ).to have_been_made.once
          end

          it 'updates the binding and job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq(state)
            expect(binding.last_operation.description).to eq(description)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'enqueues the next fetch last operation job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          context 'last operation response is 200 OK and indicates success' do
            let(:state) { 'succeeded' }
            let(:fetch_binding_status_code) { 200 }
            let(:fetch_binding_body) do
              { route_service_url: route_service_url }
            end

            before do
              stub_request(:get, broker_bind_url).
                to_return(status: fetch_binding_status_code, body: fetch_binding_body.to_json, headers: {})
            end

            it 'fetches the service instance' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(
                a_request(:get, broker_bind_url)
              ).to have_been_made.once
            end

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'last operation response is 200 OK and indicates failure' do
            let(:state) { 'failed' }

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'last operation response is 400 Bad Request' do
            let(:last_operation_status_code) { 400 }
            let(:state) { 'failed' }
            let(:description) { 'a helpful description' }

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'last operation response is 404 Not Found' do
            let(:last_operation_status_code) { 404 }
            let(:last_operation_body) { 'cannot see it' }

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('failed')
              expect(binding.last_operation.description).to eq('The service broker rejected the request. Status Code: 404 Not Found, Body: "cannot see it"')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'last operation response is 500 Internal Server Error' do
            let(:last_operation_status_code) { 500 }
            let(:last_operation_body) { 'something awful' }

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('failed')
              expect(binding.last_operation.description).to eq('The service broker returned an invalid response. Status Code: 500 Internal Server Error, Body: "something awful"')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end
          end

          context 'binding not retrievable' do
            let(:offering) { VCAP::CloudController::Service.make(bindings_retrievable: false, requires: ['route_forwarding']) }

            it 'fails the job with an appropriate error' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('failed')
              expect(binding.last_operation.description).to eq('The broker responded asynchronously but does not support fetching binding data')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              expect(job.cf_api_error).not_to be_nil
              error = YAML.safe_load(job.cf_api_error)
              expect(error['errors'].first).to include({
                'code' => 90001,
                'title' => 'CF-ServiceBindingInvalid',
                'detail' => 'The service binding is invalid: The broker responded asynchronously but does not support fetching binding data',
              })
            end
          end
        end
      end

      describe 'permissions' do
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            Hash.new(code: 403).tap do |h|
              h['admin'] = { code: 202 }
              h['space_developer'] = { code: 202 }

              h['no_role'] = { code: 422 }
              h['org_auditor'] = { code: 422 }
              h['org_billing_manager'] = { code: 422 }
            end
          end
        end
      end

      context 'service offering not configured for route binding' do
        let(:offering) { VCAP::CloudController::Service.make(requires: []) }

        it 'fails with a 422 unprocessable' do
          post '/v3/service_route_bindings', request.to_json, space_dev_headers

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'This service instance does not support route binding',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'service offering not bindable' do
        let(:offering) { VCAP::CloudController::Service.make(bindable: false, requires: ['route_forwarding']) }

        it 'fails with a 422 unprocessable' do
          post '/v3/service_route_bindings', request.to_json, space_dev_headers

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'This service instance does not support binding',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'cannot read service instance' do
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan) }

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The service instance could not be found: #{service_instance.guid}",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end
    end

    context 'user-provided service instance' do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

      it_behaves_like 'create route binding'

      it 'creates a service route binding' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(201)

        binding = VCAP::CloudController::RouteBinding.last
        expect(binding.service_instance).to eq(service_instance)
        expect(binding.route).to eq(route)
        expect(binding.route_service_url).to eq(route_service_url)

        expect(parsed_response).to match_json_response(
          expected_json(
            binding_guid: binding.guid,
            route_service_url: route_service_url,
            service_instance_guid: service_instance.guid,
            route_guid: route.guid,
            last_operation_type: 'create',
            last_operation_state: 'succeeded',
          )
        )
      end

      describe 'permissions' do
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            Hash.new(code: 403).tap do |h|
              h['admin'] = { code: 201 }
              h['space_developer'] = { code: 201 }

              h['no_role'] = { code: 422 }
              h['org_auditor'] = { code: 422 }
              h['org_billing_manager'] = { code: 422 }
            end
          end
        end
      end

      context 'parameters are specified' do
        let(:request_extra) do
          {
            parameters: { foo: 'bar' }
          }
        end

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'Binding parameters are not supported for user-provided service instances',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'service instance not configured for route binding' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'This service instance does not support route binding',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end

      context 'cannot read service instance' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The service instance could not be found: #{service_instance.guid}",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )

          expect(VCAP::CloudController::RouteBinding.all).to be_empty
        end
      end
    end
  end

  describe 'GET /v3/service_route_bindings' do
    describe 'no bindings to list' do
      let(:api_call) { ->(user_headers) { get '/v3/service_route_bindings', nil, user_headers } }
      let(:expected_codes_and_responses) do
        Hash.new(code: 200, response_objects: [])
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'a mix of bindings' do
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:service_instance_1) { VCAP::CloudController::UserProvidedServiceInstance.make(:routing, space: space, route_service_url: route_service_url) }
      let(:service_instance_2) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space, route_service_url: route_service_url) }
      let(:route_binding_1) do
        bind_service_to_route(service_instance_1, route)
      end
      let(:route_binding_2) do
        bind_service_to_route(service_instance_2, route)
      end
      let(:api_call) { ->(user_headers) { get '/v3/service_route_bindings', nil, user_headers } }
      let(:response_objects) do
        [
          expected_json(
            binding_guid: route_binding_1.guid,
              route_service_url: route_service_url,
              service_instance_guid: service_instance_1.guid,
              route_guid: route.guid,
              last_operation_type: 'create',
              last_operation_state: 'successful',
          ),
          expected_json(
            binding_guid: route_binding_2.guid,
            route_service_url: route_service_url,
            service_instance_guid: service_instance_2.guid,
            route_guid: route.guid,
            last_operation_type: 'create',
            last_operation_state: 'successful',
          )
        ]
      end
      let(:bindings_response_body) do
        { code: 200, response_objects: response_objects }
      end

      let(:expected_codes_and_responses) do
        Hash.new(code: 200, response_objects: []).tap do |h|
          h['admin'] = bindings_response_body
          h['admin_read_only'] = bindings_response_body
          h['global_auditor'] = bindings_response_body
          h['space_developer'] = bindings_response_body
          h['space_manager'] = bindings_response_body
          h['space_auditor'] = bindings_response_body
          h['org_manager'] = bindings_response_body
        end
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'filtering' do
      it 'can be filtered by service instance guids' do
        VCAP::CloudController::RouteBinding.make
        filtered_route_bindings = Array.new(2) { VCAP::CloudController::RouteBinding.make }
        service_instance_guids = filtered_route_bindings.
                                 map(&:service_instance).
                                 map(&:guid).
                                 join(',')

        get "/v3/service_route_bindings?service_instance_guids=#{service_instance_guids}", nil, admin_headers

        expect(last_response).to have_status_code(200)

        expected_route_binding_guids = filtered_route_bindings.map(&:guid)
        route_binding_guids = parsed_response['resources'].map { |x| x['guid'] }
        expect(route_binding_guids).to eq(expected_route_binding_guids)
      end

      it 'can be filtered by route guids' do
        VCAP::CloudController::RouteBinding.make
        filtered_route_bindings = Array.new(2) { VCAP::CloudController::RouteBinding.make }
        route_guids = filtered_route_bindings.
                      map(&:route).
                      map(&:guid).
                      join(',')

        get "/v3/service_route_bindings?route_guids=#{route_guids}", nil, admin_headers

        expect(last_response).to have_status_code(200)

        expected_route_binding_guids = filtered_route_bindings.map(&:guid)
        route_binding_guids = parsed_response['resources'].map { |x| x['guid'] }
        expect(route_binding_guids).to eq(expected_route_binding_guids)
      end
    end
  end

  describe 'GET /v3/service_route_bindings/:guid' do
    let(:api_call) { ->(user_headers) { get "/v3/service_route_bindings/#{guid}", nil, user_headers } }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:route_binding) do
      VCAP::CloudController::RouteBinding.new.save_with_new_operation(
        { service_instance: service_instance, route: route, route_service_url: route_service_url },
        { type: 'create', state: 'successful' }
      )
    end
    let(:guid) { route_binding.guid }
    let(:expected_body) do
      expected_json(
        binding_guid: guid,
        route_service_url: route_service_url,
        service_instance_guid: service_instance.guid,
        route_guid: route.guid,
        last_operation_type: 'create',
        last_operation_state: 'successful',
      )
    end

    let(:expected_codes_and_responses) do
      responses_for_space_restricted_single_endpoint(expected_body)
    end

    context 'user-provided service instance' do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'managed service instance' do
      let(:service_offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'does not exist' do
      let(:guid) { 'no-such-route-binding' }

      it 'fails with the correct error' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(404)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => 'Service route binding not found',
            'title' => 'CF-ResourceNotFound',
            'code' => 10010,
          })
        )
      end
    end
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:route_service_url) { 'https://route_service_url.com' }

  let(:space_dev_headers) do
    org.add_user(user)
    space.add_developer(user)
    headers_for(user)
  end

  def expected_json(binding_guid:, route_service_url:, route_guid:, service_instance_guid:, last_operation_state:, last_operation_type:)
    {
      guid: binding_guid,
      created_at: iso8601,
      updated_at: iso8601,
      route_service_url: route_service_url,
      last_operation: {
        created_at: iso8601,
        updated_at: iso8601,
        description: nil,
        state: last_operation_state,
        type: last_operation_type,
      },
      relationships: {
        service_instance: {
          data: {
            guid: service_instance_guid
          }
        },
        route: {
          data: {
            guid: route_guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_route_bindings/#{binding_guid}"
        },
        service_instance: {
          href: "#{link_prefix}/v3/service_instances/#{service_instance_guid}"
        },
        route: {
          href: "#{link_prefix}/v3/routes/#{route_guid}"
        }
      }
    }
  end

  def bind_service_to_route(service_instance, route)
    route_service_url = service_instance.route_service_url
    VCAP::CloudController::RouteBinding.new.save_with_new_operation(
      { service_instance: service_instance, route: route, route_service_url: route_service_url },
        { type: 'create', state: 'successful' }
    )
  end
end
