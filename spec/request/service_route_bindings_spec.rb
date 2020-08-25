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
      let(:offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
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
            to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
        end

        it 'sends a bind request with the right arguments to the service broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(
            a_request(:put, broker_bind_url).
              with(body: client_body)
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
                with(body: client_body.deep_merge(request_extra))
            ).to have_been_made.once
          end
        end

        context 'when the bind completes synchronously' do
          it 'updates the route service URL on the binding' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            binding.reload
            expect(binding.route_service_url).to eq(route_service_url)
          end

          it 'completes' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
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
            service_instance_guid: service_instance.guid,
            route_guid: route.guid,
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

  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:route_service_url) { 'https://route_service_url.com' }

  let(:space_dev_headers) do
    org.add_user(user)
    space.add_developer(user)
    headers_for(user)
  end

  def expected_json(binding_guid:, route_guid:, service_instance_guid:)
    {
      guid: binding_guid,
      created_at: iso8601,
      updated_at: iso8601,
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
end
