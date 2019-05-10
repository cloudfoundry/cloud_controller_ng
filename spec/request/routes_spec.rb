require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Routes Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

  describe 'GET /v3/routes/:guid' do
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain) }
    let(:api_call) { lambda { |user_headers| get "/v3/routes/#{route.guid}", nil, user_headers } }
    let(:route_json) do
      {
        guid: UUID_REGEX,
        host: route.host,
        created_at: iso8601,
        updated_at: iso8601,
        relationships: {
          space: {
            data: { guid: route.space.guid }
          },
          domain: {
            data: { guid: route.domain.guid }
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route.space.guid}) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route.domain.guid}) }
        }
      }
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: route_json
        )

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the user is not a member in the routes org' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_space.organization) }
      let(:route) { VCAP::CloudController::Route.make(space: other_space, domain: domain) }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: route_json
        }
        h['admin_read_only'] = {
          code: 200,
          response_object: route_json
        }
        h['global_auditor'] = {
          code: 200,
          response_object: route_json
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'POST /v3/routes' do
    describe 'when creating a route without a host' do
      let(:params) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          }
        }
      end

      let(:route_json) do
        {
          guid: UUID_REGEX,
          host: '',
          created_at: iso8601,
          updated_at: iso8601,
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) },
          }
        }
      end

      describe 'valid routes' do
        let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: route_json
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'when creating a route with a host' do
      let(:params) do
        {
          host: 'some-host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          }
        }
      end

      let(:route_json) do
        {
          guid: UUID_REGEX,
          host: 'some-host',
          created_at: iso8601,
          updated_at: iso8601,
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) },
          }
        }
      end

      describe 'valid routes' do
        let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: route_json
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/routes', {}.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/routes', {}.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the space does not exist' do
      let(:params_with_invalid_space) do
        {
          relationships: {
            space: {
              data: { guid: 'invalid-space' }
            },
            domain: {
              data: { guid: domain.guid }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_invalid_space.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Invalid space. Ensure that the space exists and you have access to it.')
      end
    end

    context 'when the domain does not exist' do
      let(:params_with_invalid_domain) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: 'invalid-domain' }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_invalid_domain.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Invalid domain. Ensure that the domain exists and you have access to it.')
      end
    end

    context 'when the domain has an owning org that is different from the space\'s parent org' do
      let(:other_org) { VCAP::CloudController::Organization.make }
      let(:inaccessible_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_org) }

      let(:params_with_inaccessible_domain) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: inaccessible_domain.guid }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_inaccessible_domain.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Invalid domain. Domain '#{inaccessible_domain.name}' is not available in organization '#{org.name}'.")
      end
    end

    context 'when the host-less route has already been created for this domain' do
      let!(:existing_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain) }

      let(:params_for_duplicate_route) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_for_duplicate_route.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Route already exists for domain '#{domain.name}'.")
      end
    end

    context 'when the space quota for routes is maxed out' do
      let!(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make(total_routes: 0, organization: org) }
      let!(:space_with_quota) { VCAP::CloudController::Space.make(space_quota_definition: space_quota_definition, organization: org) }

      let(:params_for_space_with_quota) do
        {
          relationships: {
            space: {
              data: { guid: space_with_quota.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_for_space_with_quota.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Routes quota exceeded for space '#{space_with_quota.name}'.")
      end
    end

    context 'when the org quota for routes is maxed out' do
      let!(:org_quota_definition) { VCAP::CloudController::QuotaDefinition.make(total_routes: 0, total_reserved_route_ports: 0) }
      let!(:org_with_quota) { VCAP::CloudController::Organization.make(quota_definition: org_quota_definition) }
      let!(:space_in_org_with_quota) do
        VCAP::CloudController::Space.make(organization: org_with_quota)
      end
      let(:domain_in_org_with_quota) { VCAP::CloudController::Domain.make(owning_organization: org_with_quota) }

      let(:params_for_org_with_quota) do
        {
          relationships: {
            space: {
              data: { guid: space_in_org_with_quota.guid }
            },
            domain: {
              data: { guid: domain_in_org_with_quota.guid }
            },
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_for_org_with_quota.to_json, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Routes quota exceeded for organization '#{org_with_quota.name}'.")
      end
    end
  end
end
