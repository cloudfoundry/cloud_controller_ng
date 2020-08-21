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
      }
    end

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
        end
      end
    end

    context 'managed service instance' do
      let(:offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
      let(:plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: plan) }

      it_behaves_like 'create route binding'

      describe 'permissions' do
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            Hash.new(code: 403).tap do |h|
              h['admin'] = { code: 501 }
              h['space_developer'] = { code: 501 }

              h['no_role'] = { code: 422 }
              h['org_auditor'] = { code: 422 }
              h['org_billing_manager'] = { code: 422 }
            end
          end
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
        end
      end
    end

    context 'user-provided service instance' do
      let(:route_service_url) { 'https://route_service_url.com' }
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

      it_behaves_like 'create route binding'

      it 'creates a service route binding' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(201)

        binding = VCAP::CloudController::RouteBinding.first
        expect(parsed_response['guid']).to eq(binding.guid)

        expect(binding.service_instance).to eq(service_instance)
        expect(binding.route).to eq(route)
        expect(binding.route_service_url).to eq(route_service_url)
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

      context 'binding already exists' do
        before do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(201)
        end

        it 'fails with a specific error' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(400)

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
        before do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(201)
        end

        let(:new_route) { VCAP::CloudController::Route.make(space: space) }
        let(:new_request) do
          request.deep_merge({ relationships: { route: { data: { guid: new_route.guid } } } })
        end

        it 'succeeds' do
          post '/v3/service_route_bindings', new_request.to_json, space_dev_headers

          expect(last_response).to have_status_code(201)
        end
      end

      context 'route is bound to a different service instance' do
        before do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(201)
        end

        let(:new_service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }
        let(:new_request) do
          request.deep_merge({ relationships: { service_instance: { data: { guid: new_service_instance.guid } } } })
        end

        it 'fails with a 422 unprocessable' do
          post '/v3/service_route_bindings', new_request.to_json, space_dev_headers

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
        end
      end
    end
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  let(:space_dev_headers) do
    org.add_user(user)
    space.add_developer(user)
    headers_for(user)
  end
end
