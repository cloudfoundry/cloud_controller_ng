require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service route bindings' do
  describe 'POST /v3/service_route_bindings' do
    let(:api_call) { ->(user_headers) { post '/v3/service_route_bindings', request.to_json, user_headers } }

    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
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

    describe 'errors' do
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

      context 'route and service instance in different spaces' do
        let(:route) { VCAP::CloudController::Route.make }

        it 'fails with a 422 unprocessable' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'The service instance and the route are in different spaces.',
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
