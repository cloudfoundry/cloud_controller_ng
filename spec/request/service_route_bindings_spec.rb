require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service route bindings' do
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
      let(:route_binding_1_metadata) { { labels: { peanut: 'butter' }, annotations: {} } }
      let(:route_binding_2_metadata) { { labels: {}, annotations: { pastry: 'choux' } } }
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
            include_params_link: service_instance_1.managed_instance?,
            metadata: route_binding_1_metadata
          ),
          expected_json(
            binding_guid: route_binding_2.guid,
            route_service_url: route_service_url,
            service_instance_guid: service_instance_2.guid,
            route_guid: route.guid,
            last_operation_type: 'create',
            last_operation_state: 'successful',
            include_params_link: service_instance_2.managed_instance?,
            metadata: route_binding_2_metadata
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

      before do
        VCAP::CloudController::LabelsUpdate.update(route_binding_1, route_binding_1_metadata[:labels], VCAP::CloudController::RouteBindingLabelModel)
        VCAP::CloudController::AnnotationsUpdate.update(route_binding_2, route_binding_2_metadata[:annotations], VCAP::CloudController::RouteBindingAnnotationModel)
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
        expect(route_binding_guids).to match_array(expected_route_binding_guids)
      end

      it 'can be filtered by service instance names' do
        VCAP::CloudController::RouteBinding.make
        filtered_route_bindings = Array.new(2) { VCAP::CloudController::RouteBinding.make }
        service_instance_names = filtered_route_bindings.
                                 map(&:service_instance).
                                 map(&:name).
                                 join(',')

        get "/v3/service_route_bindings?service_instance_names=#{service_instance_names}", nil, admin_headers

        expect(last_response).to have_status_code(200)

        expected_route_binding_guids = filtered_route_bindings.map(&:guid)
        route_binding_guids = parsed_response['resources'].map { |x| x['guid'] }
        expect(route_binding_guids).to match_array(expected_route_binding_guids)
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
        expect(route_binding_guids).to match_array(expected_route_binding_guids)
      end
    end

    describe 'include' do
      it 'can include `service_instance`' do
        instance = VCAP::CloudController::UserProvidedServiceInstance.make(:routing)
        other_instance = VCAP::CloudController::UserProvidedServiceInstance.make(:routing)

        VCAP::CloudController::RouteBinding.make(service_instance: instance)
        2.times { VCAP::CloudController::RouteBinding.make(service_instance: other_instance) }

        get '/v3/service_route_bindings?include=service_instance', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_instances']).to have(2).items
        guids = parsed_response['included']['service_instances'].map { |x| x['guid'] }
        expect(guids).to contain_exactly(instance.guid, other_instance.guid)
      end

      it 'can include `route`' do
        route = VCAP::CloudController::Route.make
        other_route = VCAP::CloudController::Route.make

        si = VCAP::CloudController::ManagedServiceInstance.make(:routing, space: route.space)
        VCAP::CloudController::RouteBinding.make(route: route, service_instance: si)

        2.times do
          si = VCAP::CloudController::ManagedServiceInstance.make(:routing, space: other_route.space)
          VCAP::CloudController::RouteBinding.make(route: other_route, service_instance: si)
        end

        get '/v3/service_route_bindings?include=route', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['routes']).to have(2).items
        guids = parsed_response['included']['routes'].map { |x| x['guid'] }
        expect(guids).to contain_exactly(route.guid, other_route.guid)
      end

      it 'rejects requests with invalid associations' do
        get '/v3/service_route_bindings?include=planet', nil, admin_headers
        expect(last_response).to have_status_code(400)
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
    let(:metadata) {
      {
        labels: { peanut: 'butter' },
        annotations: { butter: 'yes' }
      }
    }
    let(:expected_body) do
      expected_json(
        binding_guid: guid,
        route_service_url: route_service_url,
        service_instance_guid: service_instance.guid,
        route_guid: route.guid,
        last_operation_type: 'create',
        last_operation_state: 'successful',
        include_params_link: service_instance.managed_instance?,
        metadata: metadata
      )
    end
    let(:expected_codes_and_responses) do
      responses_for_space_restricted_single_endpoint(expected_body)
    end

    context 'user-provided service instance' do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

      before do
        VCAP::CloudController::LabelsUpdate.update(route_binding, metadata[:labels], VCAP::CloudController::RouteBindingLabelModel)
        VCAP::CloudController::AnnotationsUpdate.update(route_binding, metadata[:annotations], VCAP::CloudController::RouteBindingAnnotationModel)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'managed service instance' do
      let(:service_offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }

      before do
        VCAP::CloudController::LabelsUpdate.update(route_binding, metadata[:labels], VCAP::CloudController::RouteBindingLabelModel)
        VCAP::CloudController::AnnotationsUpdate.update(route_binding, metadata[:annotations], VCAP::CloudController::RouteBindingAnnotationModel)
      end

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

    describe 'include' do
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space) }

      before do
        VCAP::CloudController::LabelsUpdate.update(route_binding, metadata[:labels], VCAP::CloudController::RouteBindingLabelModel)
        VCAP::CloudController::AnnotationsUpdate.update(route_binding, metadata[:annotations], VCAP::CloudController::RouteBindingAnnotationModel)
      end

      it 'can include `service_instance`' do
        get "/v3/service_route_bindings/#{guid}?include=service_instance", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_instances']).to have(1).items
        service_instance_guid = parsed_response['included']['service_instances'][0]['guid']
        expect(service_instance_guid).to eq(service_instance.guid)
      end

      it 'can include `route`' do
        get "/v3/service_route_bindings/#{guid}?include=route", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['routes']).to have(1).items
        route_guid = parsed_response['included']['routes'][0]['guid']
        expect(route_guid).to eq(route.guid)
      end

      it 'rejects requests with invalid associations' do
        get "/v3/service_route_bindings/#{guid}?include=planet", nil, admin_headers
        expect(last_response).to have_status_code(400)
      end
    end
  end

  describe 'POST /v3/service_route_bindings' do
    let(:api_call) { ->(user_headers) { post '/v3/service_route_bindings', request.to_json, user_headers } }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:metadata) { {
      labels: { peanut: 'butter' },
      annotations: { number: 'eight' }
    }
    }
    let(:request) do
      {
        metadata: metadata,
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

      context 'invalid metadata' do
        let(:metadata) do
          { foo: 'bar' }
        end

        it 'fails with a 422 unprocessable' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "Metadata has unexpected field(s): 'foo'",
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

        expect(binding).to have_labels({ prefix: nil, key: 'peanut', value: 'butter' })
        expect(binding).to have_annotations({ prefix: nil, key: 'number', value: 'eight' })
      end

      it 'responds with a job resource' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(202)
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_route_bindings.create')
        expect(job.resource_guid).to eq(binding.guid)
        expect(job.resource_type).to eq('service_route_binding')

        get "/v3/jobs/#{job.guid}", nil, space_dev_headers

        expect(last_response).to have_status_code(200)
        expect(parsed_response['guid']).to eq(job.guid)
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
          it 'updates the binding' do
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

          context 'orphan mitigation' do
            it_behaves_like 'create binding orphan mitigation' do
              let(:bind_url) { broker_bind_url }
              let(:plan_id) { plan.unique_id }
              let(:offering_id) { offering.unique_id }
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
            end
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

          it 'keeps track of the broker operation' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)

            Timecop.travel(Time.now + 1.minute)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:get, broker_binding_last_operation_url).
                with(query: {
                  operation: operation,
                  service_id: service_instance.service_plan.service.unique_id,
                  plan_id: service_instance.service_plan.unique_id,
                })
            ).to have_been_made.twice
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

            it 'fetches the binding' do
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

          it_behaves_like 'binding last operation response handling', 'create'

          context 'last operation response is 410 Gone' do
            let(:last_operation_status_code) { 410 }
            let(:last_operation_body) { {} }

            it 'continues polling' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              binding.reload
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('in progress')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
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

      context 'there is an operation in progress for the service instance' do
        it 'responds with 422' do
          service_instance.save_with_new_operation({}, { type: 'guacamole', state: 'in progress' })

          post '/v3/service_route_bindings', request.to_json, space_dev_headers

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('There is an operation in progress for the service instance'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
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
        expect(binding).to have_labels({ prefix: nil, key: 'peanut', value: 'butter' })
        expect(binding).to have_annotations({ prefix: nil, key: 'number', value: 'eight' })

        expect(parsed_response).to match_json_response(
          expected_json(
            binding_guid: binding.guid,
            route_service_url: route_service_url,
            service_instance_guid: service_instance.guid,
            route_guid: route.guid,
            last_operation_type: 'create',
            last_operation_state: 'succeeded',
            include_params_link: service_instance.managed_instance?,
            metadata: metadata
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

  describe 'DELETE /v3/service_route_bindings/:guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/service_route_bindings/#{guid}", nil, user_headers } }

    context 'route binding exists' do
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:binding) do
        VCAP::CloudController::RouteBinding.new.save_with_new_operation(
          { service_instance: service_instance, route: route, route_service_url: route_service_url },
          { type: 'create', state: 'successful' }
        )
      end
      let(:guid) { binding.guid }

      context 'user-provided service instance' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

        let(:expected_codes_and_responses) { responses_for_space_restricted_delete_endpoint }
        let(:db_check) {
          lambda do
            expect(VCAP::CloudController::RouteBinding.all).to be_empty
          end
        }

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'managed service instance' do
        let(:service_offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }

        let(:expected_codes_and_responses) { responses_for_space_restricted_async_delete_endpoint }
        let(:db_check) { lambda {} }
        let(:job) { VCAP::CloudController::PollableJobModel.last }
        let(:broker_base_url) { service_instance.service_broker.broker_url }
        let(:broker_unbind_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }
        let(:route_service_url) { 'https://route_service_url.com' }
        let(:broker_unbind_status_code) { 200 }
        let(:broker_response) { {} }
        let(:query) do
          {
            service_id: service_instance.service_plan.service.unique_id,
            plan_id: service_instance.service_plan.unique_id,
            accepts_incomplete: true,
          }
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS

        it 'responds with a job resource' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(202)
          expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('service_route_bindings.delete')
          expect(job.resource_guid).to eq(binding.guid)
          expect(job.resource_type).to eq('service_route_binding')

          get "/v3/jobs/#{job.guid}", nil, space_dev_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['guid']).to eq(job.guid)
        end

        describe 'the pollable job' do
          before do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(202)

            stub_request(:delete, broker_unbind_url).
              with(query: query).
              to_return(status: broker_unbind_status_code, body: broker_response.to_json, headers: {})
          end

          it 'sends an unbind request with the right arguments to the service broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:delete, broker_unbind_url).
                with(
                  query: query,
                )
            ).to have_been_made.once
          end

          context 'when the unbind completes synchronously' do
            it 'removes the binding' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::RouteBinding.all).to be_empty
            end

            it 'completes the job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'when the unbind responds asynchronously' do
            let(:broker_unbind_status_code) { 202 }
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

              binding.reload
              expect(binding.last_operation.type).to eq('delete')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
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

              expect(
                a_request(:get, broker_binding_last_operation_url).
                  with(query: {
                    operation: operation,
                    service_id: service_instance.service_plan.service.unique_id,
                    plan_id: service_instance.service_plan.unique_id,
                  })
              ).to have_been_made.twice
            end

            context 'last operation response is 200 OK and indicates success' do
              let(:state) { 'succeeded' }
              let(:last_operation_status_code) { 200 }

              it 'removes the binding' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(VCAP::CloudController::RouteBinding.all).to be_empty
              end

              it 'completes the job' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
              end
            end

            context 'last operation response is 410 Gone' do
              let(:last_operation_status_code) { 410 }
              let(:last_operation_body) { {} }

              it 'removes the binding' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(VCAP::CloudController::RouteBinding.all).to be_empty
              end

              it 'completes the job' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
              end
            end

            it_behaves_like 'binding last operation response handling', 'delete'
          end

          context 'when the broker returns a failure' do
            let(:broker_unbind_status_code) { 418 }
            let(:broker_response) { 'nope' }

            it 'does not remove the binding' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(VCAP::CloudController::RouteBinding.all).not_to be_empty
            end

            it 'puts the error details in the job' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              expect(job.cf_api_error).not_to be_nil
              error = YAML.safe_load(job.cf_api_error)
              expect(error['errors'].first['code']).to eq(10009)
              expect(error['errors'].first['detail']).
                to include('The service broker rejected the request. Status Code: 418 I\'m a Teapot, Body: "nope"')
            end
          end
        end

        context 'when the service instance has an operation in progress' do
          it 'responds with 422' do
            service_instance.save_with_new_operation({}, { type: 'guacamole', state: 'in progress' })

            api_call.call admin_headers
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(include({
              'detail' => include('There is an operation in progress for the service instance'),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            }))
          end
        end

        context 'when the route binding is still creating' do
          before do
            binding.save_with_new_operation(
              {},
              { type: 'create', state: 'in progress', broker_provided_operation: 'very important info' }
            )
          end

          context 'but the broker accepts the delete request' do
            before do
              @delete_stub = stub_request(:delete, broker_unbind_url).
                             with(query: query).
                             to_return(status: 202, body: '{"operation": "very important delete info"}', headers: {})

              @last_op_stub = stub_request(:get, "#{broker_unbind_url}/last_operation").
                              with(query: hash_including({
                  operation: 'very important delete info'
                })).
                              to_return(status: 200, body: '{"state": "in progress"}', headers: {})
            end

            it 'starts the route binding deletion' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(202)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(@delete_stub).to have_been_requested.once
              expect(@last_op_stub).to have_been_requested

              binding.reload
              expect(binding.last_operation.type).to eq('delete')
              expect(binding.last_operation.state).to eq('in progress')
              expect(binding.last_operation.broker_provided_operation).to eq('very important delete info')
            end
          end

          context 'and the broker rejects the delete request' do
            before do
              stub_request(:delete, broker_unbind_url).
                with(query: query).
                to_return(status: 422, body: '{"error": "ConcurrencyError"}', headers: {})

              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)
              binding.reload
            end

            it 'leaves the route binding in its current state' do
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('in progress')
              expect(binding.last_operation.broker_provided_operation).to eq('very important info')
            end
          end
        end
      end
    end

    context 'no route binding' do
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

  describe 'GET /v3/service_route_bindings/:guid/parameters' do
    let(:offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding'], bindings_retrievable: true) }
    let(:plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: plan) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:binding) { bind_service_to_route(service_instance, route) }

    let(:api_call) { ->(user_headers) { get "/v3/service_route_bindings/#{binding.guid}/parameters", nil, user_headers } }

    context 'managed service instances' do
      let(:broker_base_url) { service_instance.service_broker.broker_url }
      let(:broker_fetch_binding_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:broker_status_code) { 200 }
      let(:broker_response) { { parameters: { abra: 'kadabra', kadabra: 'alakazan' } } }
      let(:parameters_response) { { code: 200, response_object: broker_response[:parameters] } }

      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = parameters_response
          h['admin_readonly'] = parameters_response
          h['space_developer'] = parameters_response
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
        end
      end

      before do
        stub_request(:get, broker_fetch_binding_url).
          to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when bindings are not retrievable' do
        let(:offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }

        it 'returns the appropriate error' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'Bad request: this service does not support fetching route bindings parameters.',
              'title' => 'CF-BadRequest',
              'code' => 1004,
            })
          )
        end
      end

      context 'when there is an operation in progress' do
        before do
          binding.save_with_new_operation({}, {
            type: 'create',
            state: 'in progress'
          })
        end

        it 'returns the appropriate error' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'There is an operation in progress for the service route binding.',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end
    end

    context 'user provided service instances' do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: 'https://route.example.com') }
      let(:error_response) { {
        code: 'CF-BadRequest',
        error: 'User provided service instances do not support fetching service binding parameters.'
      }
      }
      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = { code: 400, response_object: error_response }
          h['admin_readonly'] = { code: 400, response_object: error_response }
          h['space_developer'] = { code: 400, response_object: error_response }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
        end
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      it 'returns the appropriate error' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => 'Bad request: user provided service instances do not support fetching route bindings parameters.',
            'title' => 'CF-BadRequest',
            'code' => 1004,
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

  def expected_json(binding_guid:, route_service_url:, route_guid:, service_instance_guid:, last_operation_state:, last_operation_type:, include_params_link:, metadata: {})
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
      metadata: metadata,
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
        },
      }.tap do |ls|
        if include_params_link
          ls[:parameters] = {
            href: "#{link_prefix}/v3/service_route_bindings/#{binding_guid}/parameters"
          }
        end
      end
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
