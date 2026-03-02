require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'PATCH /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain, host: '') }
    let(:api_call) { ->(user_headers) { patch "/v3/routes/#{route.guid}", params.to_json, user_headers } }
    let(:params) do
      {
        metadata: {
          labels: {
            potato: 'fingerling',
            style: 'roasted'
          },
          annotations: {
            potato: 'russet',
            style: 'fried'
          }
        }
      }
    end

    let(:route_json) do
      {
        guid: UUID_REGEX,
        protocol: domain.protocols[0],
        host: '',
        path: '',
        port: nil,
        url: domain.name,
        created_at: iso8601,
        updated_at: iso8601,
        destinations: [],
        relationships: {
          space: {
            data: { guid: space.guid }
          },
          domain: {
            data: { guid: domain.guid }
          }
        },
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
        },
        metadata: {
          labels: {
            potato: 'fingerling',
            style: 'roasted'
          },
          annotations: {
            potato: 'russet',
            style: 'fried'
          }
        },
        options: {}
      }
    end

    context 'when the user logged in' do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['admin'] = { code: 200, response_object: route_json }
        h['no_role'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['space_developer'] = { code: 200, response_object: route_json }
        h['space_supporter'] = { code: 200, response_object: route_json }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the user is not a member in the routes org' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_space.organization) }
      let(:route) { VCAP::CloudController::Route.make(space: other_space, domain: domain, host: '') }

      let(:route_json) do
        {
          guid: UUID_REGEX,
          protocol: domain.protocols[0],
          host: '',
          path: '',
          port: nil,
          url: domain.name,
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          relationships: {
            space: {
              data: { guid: other_space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          },
          links: {
            self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
            space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{other_space.guid}} },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
            domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
          },
          metadata: {
            labels: {
              potato: 'fingerling',
              style: 'roasted'
            },
            annotations: {
              potato: 'russet',
              style: 'fried'
            }
          },
          options: {}
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        h['admin'] = {
          code: 200,
          response_object: route_json
        }
        h['admin_read_only'] = {
          code: 403
        }
        h['global_auditor'] = {
          code: 403
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when route does not exist' do
      it 'returns a 404 with a helpful error message' do
        patch "/v3/routes/#{user.guid}", params.to_json, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Route not found')
      end
    end

    context 'when request input message is invalid' do
      let(:params_with_invalid_input) do
        {
          disallowed_key: 'val'
        }
      end

      it 'returns a 422' do
        patch "/v3/routes/#{route.guid}", params_with_invalid_input.to_json, admin_header

        expect(last_response).to have_status_code(422)
      end
    end

    context 'when metadata is given with invalid format' do
      let(:params_with_invalid_metadata_format) do
        {
          metadata: {
            labels: {
              "": 'mashed',
              '/potato': '.value.'
            }
          }
        }
      end

      it 'returns a 422' do
        patch "/v3/routes/#{route.guid}", params_with_invalid_metadata_format.to_json, admin_header

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        patch "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end
  end

  describe 'DELETE /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space:, domain:) }
    let(:api_call) { ->(user_headers) { delete "/v3/routes/#{route.guid}", nil, user_headers } }
    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})

        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        get "/v3/routes/#{route.guid}", {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { route }
        let(:api_call) do
          -> { delete "/v3/routes/#{route.guid}", nil, admin_header }
        end
      end
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h['admin'] = { code: 202 }
        h['space_developer'] = { code: 202 }
        h['space_supporter'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          {
            type: 'audit.route.delete-request',
            actee: route.guid,
            actee_type: 'route',
            actee_name: route.host,
            metadata: { request: { recursive: true } }.to_json,
            space_guid: space.guid,
            organization_guid: org.guid
          }
        end
      end

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end
  end
end
