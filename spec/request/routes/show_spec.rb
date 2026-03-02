require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'GET /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space:, domain:) }
    let(:api_call) { ->(user_headers) { get "/v3/routes/#{route.guid}", nil, user_headers } }
    let(:route_json) do
      {
        guid: route.guid,
        protocol: route.domain.protocols[0],
        host: route.host,
        path: route.path,
        port: nil,
        url: "#{route.host}.#{route.domain.name}#{route.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: [],
        relationships: {
          space: {
            data: { guid: route.space.guid }
          },
          domain: {
            data: { guid: route.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        options: {},
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route.space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route.domain.guid}} }
        }
      }
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 200,
            response_object: route_json }.freeze
        )

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end

    describe 'includes' do
      context 'when including domains' do
        let(:domain_json) do
          {
            guid: domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: domain.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: { guid: domain.owning_organization.guid }
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{domain.guid}" },
              organization: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{domain.owning_organization.guid}} },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}/route_reservations} },
              shared_organizations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}/relationships/shared_organizations} }
            }
          }
        end
        let(:route_json) do
          {
            guid: route.guid,
            protocol: route.domain.protocols[0],
            host: route.host,
            path: route.path,
            port: nil,
            url: "#{route.host}.#{route.domain.name}#{route.path}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: route.space.guid }
              },
              domain: {
                data: { guid: route.domain.guid }
              }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {},
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route.space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route.domain.guid}} }
            },
            included: { domains: [domain_json] }
          }
        end

        it 'includes the domain for the route' do
          get "/v3/routes/#{route.guid}?include=domain", nil, admin_header
          expect(last_response).to have_status_code(200), last_response.body
          expect(parsed_response).to match_json_response(route_json)
        end
      end

      context 'when including spaces and orgs' do
        it 'includes the unique spaces and organizations for the routes' do
          get "/v3/routes/#{route.guid}?include=space,space.organization", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['included']).to match_json_response(
            'spaces' => [
              space_json_generator.call(space)
            ],
            'organizations' => [
              org_json_generator.call(org)
            ]
          )
        end

        context 'user is org_auditor' do
          let(:user_header) { set_user_with_header_as_role(user: user, role: 'org_auditor', org: org) }

          it 'includes the unique organizations for the routes, but no spaces' do
            get "/v3/routes/#{route.guid}?include=space,space.organization", nil, user_header
            expect(last_response).to have_status_code(200)
            expect(parsed_response['included']).to match_json_response(
              'spaces' => [],
              'organizations' => [
                org_json_generator.call(org)
              ]
            )
          end
        end
      end
    end
  end
end
