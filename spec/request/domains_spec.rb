require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Domains Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }
  let(:user_header) { headers_for(user, scopes: []) }
  let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }
  let(:router_group) { instance_double(VCAP::CloudController::RoutingApi::RouterGroup, type: 'http') }

  before do
    VCAP::CloudController::Domain.dataset.destroy # this will clean up the seeded test domains
    allow(VCAP::CloudController::RoutingApi::Client).to receive(:new).and_return(routing_api_client)
    allow(routing_api_client).to receive(:router_group).with('some-router-guid').and_return router_group
    allow(routing_api_client).to receive(:router_group).with('some-other-router-guid').and_return nil
    allow(routing_api_client).to receive(:enabled?).and_return true
  end

  describe 'GET /v3/domains' do
    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/domains' }
      let(:message) { VCAP::CloudController::DomainsListMessage }
      let(:user_header) { admin_header }
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          names: 'foo,bar',
          guids: 'foo,bar',
          organization_guids: 'foo,bar',
          label_selector: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/domains'
        expect(last_response.status).to eq(401)
      end
    end

    describe 'when the user is logged in' do
      let!(:non_visible_org) { VCAP::CloudController::Organization.make(guid: 'non-visible') }
      let!(:user_visible_org) { VCAP::CloudController::Organization.make(guid: 'visible') }

      # (domain)                        | (owning org)       | (visible orgs shared to)
      # (visible_owned_private_domain)  | (org)              | (non_visible_org, user_visible_org)
      # (visible_shared_private_domain) | (non_visible_org)  | (org)
      # (not_visible_private_domain)    | (non_visible_org)  | ()
      # (shared_domain)                 | ()                 | ()
      let!(:visible_owned_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain1', name: 'domain1.com', owning_organization: org)
      }
      let!(:visible_shared_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain2', name: 'domain2.com', owning_organization: non_visible_org)
      }
      let!(:not_visible_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain3', name: 'domain3.com', owning_organization: non_visible_org)
      }
      let!(:shared_domain) {
        VCAP::CloudController::SharedDomain.make(guid: 'domain4', name: 'domain4.com')
      }

      let(:visible_owned_private_domain_json) do
        {
          guid: visible_owned_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_owned_private_domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            shared_organizations: {
              data: contain_exactly(*shared_visible_orgs),
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_owned_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{visible_owned_private_domain.guid}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{visible_owned_private_domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:visible_shared_private_domain_json) do
        {
          guid: visible_shared_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_shared_private_domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: [{ guid: org.guid }]
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_shared_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{non_visible_org.guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{visible_shared_private_domain.guid}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{visible_shared_private_domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:not_visible_private_domain_json) do
        {
          guid: not_visible_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: not_visible_private_domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{not_visible_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{non_visible_org.guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{not_visible_private_domain.guid}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{not_visible_private_domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:shared_domain_json) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{shared_domain.guid}/route_reservations) }
          }
        }
      end

      before do
        non_visible_org.add_private_domain(visible_owned_private_domain)
        org.add_private_domain(visible_shared_private_domain)
        user_visible_org.add_private_domain(visible_owned_private_domain)
      end

      describe 'scope level permissions' do
        let(:shared_visible_orgs) { [{ guid: non_visible_org.guid }, { guid: user_visible_org.guid }] }

        context 'when the user does not have the required scopes' do
          let(:user_header) { headers_for(user, scopes: []) }

          it 'returns a 403' do
            get '/v3/domains', nil, user_header
            expect(last_response.status).to eq(403)
          end
        end

        context 'when the user has the required scopes' do
          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                not_visible_private_domain_json,
                shared_domain_json
              ]
            ).freeze
          end

          it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
        end
      end

      describe 'org/space roles' do
        context 'when the domain is shared with an org that user is a billing manager' do
          before do
            user_visible_org.add_billing_manager(user)
          end

          let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }

          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                shared_domain_json,
              ]
            )
            h['org_billing_manager'] = {
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            }
            h['no_role'] = {
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES
        end

        context 'when the domain is shared with an org that user is an org manager' do
          before do
            user_visible_org.add_manager(user)
          end

          let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }

          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                shared_domain_json,
              ]
            )
            # because the user is a manager in the shared org, they have access to see the domain
            h['org_billing_manager'] = {
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                shared_domain_json
              ]
            }
            h['no_role'] = {
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                shared_domain_json
              ]
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES
        end
      end

      describe 'when filtering by name' do
        let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }
        let(:endpoint) { "/v3/domains?names=#{visible_shared_private_domain.name}" }
        let(:api_call) { lambda { |user_headers| get endpoint, nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              visible_shared_private_domain_json,
            ]
          )
          # because the user is a manager in the shared org, they have access to see the domain
          h['org_billing_manager'] = {
            code: 200,
            response_objects: []
          }
          h['no_role'] = {
            code: 200,
            response_objects: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

        context 'pagination' do
          let(:pagination_hsh) do
            {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil
            }
          end

          it 'paginates the results' do
            get endpoint, nil, admin_header
            expect(pagination_hsh).to eq(parsed_response['pagination'])
          end
        end
      end

      describe 'when filtering by guid' do
        let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }
        let(:endpoint) { "/v3/domains?guids=#{visible_shared_private_domain.guid}" }
        let(:api_call) { lambda { |user_headers| get endpoint, nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              visible_shared_private_domain_json,
            ]
          )
          # because the user is a manager in the shared org, they have access to see the domain
          h['org_billing_manager'] = {
            code: 200,
            response_objects: []
          }
          h['no_role'] = {
            code: 200,
            response_objects: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

        context 'pagination' do
          let(:pagination_hsh) do
            {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil
            }
          end

          it 'paginates the results' do
            get endpoint, nil, admin_header
            expect(pagination_hsh).to eq(parsed_response['pagination'])
          end
        end
      end

      describe 'when filtering by owning organization guid' do
        let(:endpoint) { "/v3/domains?organization_guids=#{visible_shared_private_domain.owning_organization_guid}" }
        let(:api_call) { lambda { |user_headers| get endpoint, nil, user_headers } }

        context 'when the user can read globally' do
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                visible_shared_private_domain_json,
                not_visible_private_domain_json
              ]
            ).freeze
          end

          it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
        end

        context 'when the user cannot read globally' do
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_shared_private_domain_json,
              ]
            )
            # because the user is a manager in the shared org, they have access to see the domain
            h['org_billing_manager'] = {
              code: 200,
              response_objects: []
            }
            h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES
        end

        context 'pagination' do
          let(:pagination_hsh) do
            {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}#{endpoint}&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil
            }
          end

          it 'paginates the results' do
            get endpoint, nil, admin_header
            expect(pagination_hsh).to eq(parsed_response['pagination'])
          end
        end
      end
    end

    describe 'labels' do
      let!(:domain1) { VCAP::CloudController::PrivateDomain.make(name: 'dom1.com', owning_organization: org) }
      let!(:domain1_label) { VCAP::CloudController::DomainLabelModel.make(resource_guid: domain1.guid, key_name: 'animal', value: 'dog') }

      let!(:domain2) { VCAP::CloudController::PrivateDomain.make(name: 'dom2.com', owning_organization: org) }
      let!(:domain2_label) { VCAP::CloudController::DomainLabelModel.make(resource_guid: domain2.guid, key_name: 'animal', value: 'cow') }
      let!(:domain2__exclusive_label) { VCAP::CloudController::DomainLabelModel.make(resource_guid: domain2.guid, key_name: 'santa', value: 'claus') }

      it 'returns a 200 and the filtered domains for "in" label selector' do
        get '/v3/domains?label_selector=animal in (dog)', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "notin" label selector' do
        get '/v3/domains?label_selector=animal notin (dog)', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "=" label selector' do
        get '/v3/domains?label_selector=animal=dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "==" label selector' do
        get '/v3/domains?label_selector=animal==dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "!=" label selector' do
        get '/v3/domains?label_selector=animal!=dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "=" label selector' do
        get '/v3/domains?label_selector=animal=cow,santa=claus', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for existence label selector' do
        get '/v3/domains?label_selector=santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for non-existence label selector' do
        get '/v3/domains?label_selector=!santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/domains?label_selector=%21santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/domains?label_selector=%21santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(domain1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::PrivateDomain }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/domains?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'GET /v3/domains/:domain_guid/route_reservations' do
    let!(:non_visible_org) { VCAP::CloudController::Organization.make(guid: 'non-visible') }
    let!(:non_visible_domain) {
      VCAP::CloudController::PrivateDomain.make(guid: 'non-visible', name: 'non-visible-domain.com', owning_organization: non_visible_org)
    }
    let!(:domain) {
      VCAP::CloudController::PrivateDomain.make(guid: 'visible', name: 'visibledomain.com', owning_organization: org)
    }
    context 'no route matches' do
      let(:api_call) { lambda { |user_headers| get "/v3/domains/#{domain.guid}/route_reservations?host=my-host,path=/somepath", nil, user_headers } }

      let(:matching_route_json) do
        {
          matching_route: false
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: matching_route_json
        )
        h['org_billing_manager'] = {
          code: 404,
        }
        h['no_role'] = {
          code: 404,
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']
    end

    context 'there are route matches' do
      context 'when querying with both host and path' do
        let!(:matching_route) { VCAP::CloudController::Route.make(space: space, domain: domain, host: 'my-host', path: '/somepath') }
        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{domain.guid}/route_reservations?host=my-host&path=/somepath", nil, user_headers } }

        let(:matching_route_json) do
          {
            matching_route: true
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: matching_route_json
          )
          h['org_billing_manager'] = {
            code: 404,
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']
      end

      context 'when querying with only host' do
        let!(:other_route) { VCAP::CloudController::Route.make(space: space, domain: domain, host: 'my-host', path: '/path/to/something') }
        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{domain.guid}/route_reservations?host=my-host", nil, user_headers } }

        let(:matching_route_json) do
          {
            matching_route: false
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: matching_route_json
          )
          h['org_billing_manager'] = {
            code: 404,
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']
      end

      context 'when querying with only port' do
        let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'reservable_ports' => '123' }) }
        let(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'some-router-group', name: 'my.domain') }
        let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

        before do
          TestConfig.override(
            kubernetes: { host_url: nil },
            external_domain: 'api2.vcap.me',
            external_protocol: 'https',
          )
          allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
          allow(routing_api_client).to receive(:enabled?).and_return(true)
          allow(routing_api_client).to receive(:router_group).and_return(router_group)
        end

        let!(:other_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain, port: 123) }
        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{domain.guid}/route_reservations?port=123", nil, user_headers } }

        let(:matching_route_json) do
          {
            matching_route: true
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: matching_route_json
          )
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']

        context 'when querying a TCP route without filtering the port' do
          it 'returns no matching routes' do
            get "/v3/domains/#{domain.guid}/route_reservations", nil, admin_headers

            expect(parsed_response).to eq({ 'matching_route' => false })
          end
        end
      end
    end

    context 'when the domain cannot be found' do
      it 'returns a 404 with a helpful error message' do
        get '/v3/domains/nonexistent-domain-guid/route_reservations', nil, admin_header

        expect(last_response.status).to eq(404)
        expect(last_response).to have_error_message('Domain not found')
      end
    end

    context 'when the user does not have read visibility for the domain' do
      let(:user_header) { set_user_with_header_as_role(role: 'org_auditor', org: org) }

      it 'returns a 404 with a helpful error message' do
        get "/v3/domains/#{domain.guid}/route_reservations", nil, user_header
      end
    end
  end

  describe 'POST /v3/domains' do
    let(:params) do
      {
        name: 'my-domain.com',
        metadata: {
          labels: { 'key' => 'value' },
          annotations: { 'key2' => 'value2' }
        }
      }
    end

    context 'when metadata is invalid' do
      let(:user_header) { admin_headers_for(user) }

      it 'returns a 422' do
        post '/v3/domains', {
          metadata: {
            labels: { '': 'invalid' },
            annotations: { "#{'a' * 1001}": 'value2' }
          }
        }.to_json, user_header

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to match(/label [\w\s]+ error/)
        expect(parsed_response['errors'][0]['detail']).to match(/annotation [\w\s]+ error/)
      end
    end

    describe 'when creating a shared domain' do
      let(:api_call) { lambda { |user_headers| post '/v3/domains', domain_params.to_json, user_headers } }

      let(:domain_params) do
        {
          router_group: { guid: 'some-router-guid' },
        }.merge(params)
      end

      let(:domain_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          internal: false,
          router_group: { guid: 'some-router-guid' },
          supported_protocols: ['http'],
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          },
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}/v3/domains/#{UUID_REGEX}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}/v3/domains/#{UUID_REGEX}/route_reservations) },
            router_group: { href: %r(#{Regexp.escape(link_prefix)}/routing/v1/router_groups/some-router-guid) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: domain_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the Routing API is unavailable' do
        let(:user_header) { admin_headers_for(user) }

        before do
          allow(routing_api_client).to receive(:router_group).and_raise VCAP::CloudController::RoutingApi::RoutingApiUnavailable
        end

        it 'returns a 503 and helpful error message' do
          post '/v3/domains', domain_params.to_json, user_header

          expect(last_response.status).to eq(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'The Routing API is currently unavailable. Please try again later.'
        end
      end

      context 'when the Routing API is disabled' do
        let(:user_header) { admin_headers_for(user) }

        before do
          allow(routing_api_client).to receive(:enabled?).and_return false
        end

        it 'returns a 503 with a helpful message' do
          post '/v3/domains', domain_params.to_json, user_header

          expect(last_response.status).to eq(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'The Routing API is disabled.'
        end
      end

      context 'when UAA is unavailable' do
        let(:user_header) { admin_headers_for(user) }

        before do
          allow(routing_api_client).to receive(:router_group).and_raise VCAP::CloudController::UaaUnavailable
        end

        it 'returns a 503 with a helpful message' do
          post '/v3/domains', domain_params.to_json, user_header

          expect(last_response.status).to eq(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'Communicating with the Routing API failed because UAA is currently unavailable. Please try again later.'
        end
      end
    end

    describe 'when creating a private domain' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }
      let(:shared_org2) { VCAP::CloudController::Organization.make(guid: 'shared-org2') }

      let(:domain_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          },
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            },
            shared_organizations: {
              data: contain_exactly(
                { guid: shared_org1.guid },
                { guid: shared_org2.guid }
              )
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{UUID_REGEX}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:private_domain_params) do
        {
          name: 'my-domain.com',
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            },
            shared_organizations: {
              data: [
                { guid: shared_org1.guid },
                { guid: shared_org2.guid }
              ]

            }
          },
          metadata: {
            labels: { 'key' => 'value' },
            annotations: { 'key2' => 'value2' }
          }
        }
      end

      before do
        shared_org1.add_manager(user)
        shared_org2.add_manager(user)
      end

      describe 'valid private domains' do
        let(:api_call) { lambda { |user_headers| post '/v3/domains', private_domain_params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: domain_json

          }
          h['org_manager'] = {
            code: 201,
            response_object: domain_json

          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      describe 'invalid private domains' do
        let(:headers) { set_user_with_header_as_role(user: user, role: 'org_manager', org: org) }
        context 'when the org is suspended' do
          before do
            org.status = 'suspended'
            org.save
          end

          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
              expect(parsed_response['errors'][0]['detail']).to eq('You are not authorized to perform the requested action')
            end
          end

          context 'when the user is an admin' do
            let(:headers) { set_user_with_header_as_role(role: 'admin') }
            it 'allows creation' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(201)
            end
          end
        end

        context 'when the feature flag is disabled' do
          let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: 'my name is bob') }

          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
              expect(parsed_response['errors'][0]['detail']).to eq('Feature Disabled: my name is bob')
            end
          end

          context 'when the user is an admin' do
            let(:headers) { set_user_with_header_as_role(role: 'admin') }
            it 'allows creation' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(201)
            end
          end
        end

        context 'when the org doesnt exist' do
          let(:params) do
            {
              name: 'my-domain.biz',
              relationships: {
                organization: {
                  data: {
                    guid: 'non-existent-guid'
                  }
                }
              }
            }
          end

          it 'returns a 422 and a helpful error message' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Organization with guid \'non-existent-guid\' does not exist or you do not have access to it.'
          end
        end

        context 'when the org has exceeded its private domains quota' do
          it 'returns a 422 and a helpful error message' do
            org.update(quota_definition: VCAP::CloudController::QuotaDefinition.make(total_private_domains: 0))

            post '/v3/domains', private_domain_params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "The number of private domains exceeds the quota for organization \"#{org.name}\""
          end
        end

        context 'when the domain is in the list of reserved private domains' do
          before do
            TestConfig.override({ reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat') })
          end

          it 'returns a 422 with a error message about reserved domains' do
            post '/v3/domains', private_domain_params.merge({ name: 'com.ac' }).to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'The "com.ac" domain is reserved and cannot be used for org-scoped domains.'
          end
        end

        context 'when one of the shared orgs does not exist' do
          let(:missing_shared_org_relationship) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: 'doesnt-exist' }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', missing_shared_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "Organization with guid 'doesnt-exist' does not exist, or you do not have access to it."
          end
        end

        context 'when the user does not have proper permissions in one of the shared orgs' do
          let(:shared_org3) { VCAP::CloudController::Organization.make(guid: 'shared-org3') }

          let(:unwriteable_shared_org) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: shared_org3.guid },
                    { guid: shared_org1.guid }
                  ]
                }
              }
            }.merge(params)
          end

          before do
            shared_org3.add_user(user)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', unwriteable_shared_org.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "You do not have sufficient permissions for organization '#{shared_org3.name}' to share domain."
          end
        end

        context 'when the owning org is listed as a shared org' do
          let(:sharing_to_owning_org_relationship) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: org.guid }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', sharing_to_owning_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Domain cannot be shared with owning organization.'
          end
        end

        context 'when creating without an owning org' do
          let(:sharing_without_owning_org_relationship) do
            {
              relationships: {
                shared_organizations: {
                  data: [
                    { guid: org.guid }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', sharing_without_owning_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Relationships cannot contain shared_organizations without an owning organization.'
          end
        end

        describe 'when a router group is provided' do
          let(:params) do
            {
              name: 'my-domain.biz',
              router_group: { guid: 'some-router-guid' },
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                }
              }
            }
          end

          it 'returns a 422 and a helpful error message' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Domains scoped to an organization cannot be associated to a router group.'
          end
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/domains', params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/domains', params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the params are invalid' do
      let(:headers) { set_user_with_header_as_role(role: 'admin') }
      context 'creating a sub domain of a domain owned by another organization' do
        let(:organization_to_scope_to) { VCAP::CloudController::Organization.make }
        let(:existing_private_domain) { VCAP::CloudController::PrivateDomain.make }

        let(:params) do
          {
            name: "foo.#{existing_private_domain.name}",
            relationships: {
              organization: {
                data: {
                  guid: organization_to_scope_to.guid
                }
              }
            }
          }
        end

        it 'returns a 422 and an error' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(422)

          expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{params[:name]}\""\
" cannot be created because \"#{existing_private_domain.name}\" is already reserved by another domain"
        end
      end

      context 'when provided invalid arguments' do
        let(:params) do
          {
            name: "#{'f' * 63}$"
          }
        end

        it 'returns 422' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(422)

          expected_err = [
            'Name does not comply with RFC 1035 standards',
            'Name must contain at least one "."',
            'Name subdomains must each be at most 63 characters',
            'Name must consist of alphanumeric characters and hyphens'
          ]
          expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
        end
      end

      describe 'collisions' do
        context 'with an existing domain' do
          let!(:existing_domain) { VCAP::CloudController::SharedDomain.make }

          let(:params) do
            {
              name: existing_domain.name,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{existing_domain.name}\" is already in use"
          end
        end

        context 'with an existing route' do
          let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
          let(:existing_route) { VCAP::CloudController::Route.make(domain: existing_domain) }
          let(:domain_name) { existing_route.fqdn }

          let(:params) do
            {
              name: domain_name,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match(
              /The domain name "#{domain_name}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
            )
          end
        end

        context 'with an existing route as a subdomain' do
          let(:existing_route) { VCAP::CloudController::Route.make }
          let(:domain) { "sub.#{existing_route.fqdn}" }

          let(:params) do
            {
              name: domain,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match(
              /The domain name "#{domain}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
            )
          end
        end
      end
    end

    describe 'when specifying internal: false with an organization' do
      let(:user_header) { admin_headers_for(user) }
      let(:domain_params) do
        {
          name: 'my-domain.com',
          internal: false,
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            }
          }
        }
      end

      it 'succeeds' do
        post '/v3/domains', domain_params.to_json, user_header
        expect(last_response.status).to eq 201
      end
    end

    describe 'when specifying a router group that does not exist' do
      let(:user_header) { admin_headers_for(user) }
      let(:domain_params) do
        {
          name: 'my-domain.com',
          router_group: { guid: 'some-other-router-guid' },
        }
      end

      it 'returns a 422 and a helpful error message' do
        post '/v3/domains', domain_params.to_json, user_header

        expect(last_response.status).to eq(422)

        expect(parsed_response['errors'][0]['detail']).to eq "Router group with guid 'some-other-router-guid' not found."
      end
    end

    describe 'when specifying a router group with internal: true' do
      let(:user_header) { admin_headers_for(user) }
      let(:domain_params) do
        {
          name: 'my-domain.com',
          internal: true,
          router_group: { guid: 'some-router-guid' },
        }
      end

      it 'returns a 422 and a helpful error message' do
        post '/v3/domains', domain_params.to_json, user_header

        expect(last_response.status).to eq(422)

        expect(parsed_response['errors'][0]['detail']).to eq 'Internal domains cannot be associated to a router group.'
      end
    end
  end

  describe 'POST /v3/domains/:guid/relationships/shared_organizations' do
    let(:params) { { data: [] } }
    let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let(:user_header) { admin_headers_for(user) }

    describe 'when updating shared orgs for a shared domain' do
      let(:params) { { data: [{ guid: org.guid }] } }
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

      it 'returns a 422' do
        post "/v3/domains/#{shared_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq('Domains cannot be shared with other organizations unless they are scoped to an organization.')
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the domain with specified guid does not exist' do
      it 'returns a 404' do
        post '/v3/domains/domain-does-not-exist/relationships/shared_organizations', params.to_json, user_header
        expect(last_response.status).to eq(404)
      end
    end

    context 'when sharing with owning org' do
      let(:params) { { data: [{ guid: private_domain.owning_organization_guid }] } }

      it 'returns a 422' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
      end
    end

    context 'when sharing with invalid org' do
      let(:params) { { data: [{ guid: 'not-an-org' }] } }

      it 'returns a 422' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
      end
    end

    describe 'when sharing orgs with a private domain' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }

      let(:domain_shared_orgs) do
        {
          data: [{ guid: shared_org1.guid }]
        }
      end

      let(:private_domain_params) { {
        data: [{ guid: shared_org1.guid }]
      }
      }

      before do
        shared_org1.add_private_domain(private_domain)
        shared_org1.add_manager(user)
      end

      describe 'valid private domains' do
        let(:api_call) { lambda { |user_headers| post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", private_domain_params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 200,
            response_object: domain_shared_orgs

          }
          h['org_manager'] = {
            code: 200,
            response_object: domain_shared_orgs

          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'when the user does not have read permissions for the domain' do
      let(:org1) { VCAP::CloudController::Organization.make(guid: 'org1') }
      let(:org2) { VCAP::CloudController::Organization.make(guid: 'org2') }
      let!(:shared_domain) { VCAP::CloudController::SharedDomain.make }
      let(:unreadable_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org1) }

      let(:domain_shared_orgs) do
        {
          data: [{ guid: org2.guid }]
        }
      end

      let(:unreadable_domain_params) do
        {
          data: [{ guid: org2.guid }]
        }
      end

      before do
        org2.add_manager(user)
      end

      let(:api_call) { lambda { |user_headers| post "/v3/domains/#{unreadable_domain.guid}/relationships/shared_organizations", unreadable_domain_params.to_json, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 404
        )
        h['admin'] = {
          code: 200,
          response_object: domain_shared_orgs
        }
        h['admin_read_only'] = {
          code: 403
        }
        h['global_auditor'] = {
          code: 403
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'DELETE /v3/domains/:guid' do
    describe 'when deleting a shared domain' do
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
      let(:api_call) { lambda { |user_headers| delete "/v3/domains/#{shared_domain.guid}", nil, user_headers } }
      let(:db_check) do
        lambda do
          expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          get "/v3/domains/#{shared_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )

        h['admin'] = {
          code: 202
        }

        h.freeze
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS

      context 'deleting metadata' do
        it_behaves_like 'resource with metadata' do
          let(:resource) { shared_domain }
          let(:api_call) do
            -> { delete "/v3/domains/#{resource.guid}", nil, admin_headers }
          end
        end
      end
    end

    describe 'when deleting a private domain' do
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
      let(:api_call) { lambda { |user_headers| delete "/v3/domains/#{private_domain.guid}", nil, user_headers } }

      let(:db_check) do
        lambda do
          expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          get "/v3/domains/#{private_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 202 }
        h['org_manager'] = { code: 202 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h.freeze
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    describe 'when deleting a shared private domain as an org manager of the shared organization' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
      let(:user_header) { headers_for(user) }

      before do
        private_domain.add_shared_organization(shared_org1)
        shared_org1.add_manager(user)
      end

      it 'returns a 403' do
        delete "/v3/domains/#{private_domain.guid}", nil, user_header
        expect(last_response.status).to eq(403)
      end
    end

    describe 'when deleting a shared private domain' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
      let(:user_header) { admin_headers_for(user) }

      before do
        private_domain.add_shared_organization(shared_org1)
      end

      it 'returns a 422' do
        delete "/v3/domains/#{private_domain.guid}", nil, user_header
        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq(
          'This domain is shared with other organizations. Unshare before deleting.')
      end
    end
  end

  describe 'DELETE /v3/domains/:guid/relationships/shared_organizations/:org_guid' do
    let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }
    let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let(:user_header) { admin_headers_for(user) }

    context 'when there are non role related permissions issues' do
      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, base_json_headers
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the user does not have the required scopes' do
        let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

        it 'returns a 403' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, user_header
          expect(last_response.status).to eq(403)
        end
      end
    end

    context 'when the org is invalid' do
      context 'when unsharing from invalid org' do
        it 'returns a 422' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/invalid_org", nil, user_header
          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq("Organization with guid 'invalid_org' does not exist or you do not have access to it.")
        end
      end

      context 'when unsharing from non-shared org' do
        let(:org2) { VCAP::CloudController::Organization.make }

        it 'returns a 422' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{org2.guid}", nil, user_header
          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq(
            "Unable to unshare domain from organization with name '#{org2.name}'. Ensure the domain is shared to this organization.")
        end
      end

      context 'when unsharing from owning org' do
        it 'returns a 422' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{private_domain.owning_organization_guid}", nil, user_header
          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq(
            "Unable to unshare domain from organization with name '#{org.name}'. Ensure the domain is shared to this organization.")
        end
      end
    end

    context 'when the domain is invalid' do
      context 'when the domain with specified guid does not exist' do
        it 'returns a 404' do
          delete "/v3/domains/domain-does-not-exist/relationships/shared_organizations/#{shared_org1.guid}", nil, user_header
          expect(last_response.status).to eq(404)
        end
      end

      context "when domain exists but user doesn't have read permissions for it" do
        let(:user_headers) { set_user_with_header_as_role(role: 'org_billing_manager', org: org) }
        it 'returns a 404' do
          delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, user_headers
          expect(last_response.status).to eq(404)
        end
      end

      context 'when unsharing a shared domain' do
        let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

        it 'returns a 422' do
          delete "/v3/domains/#{shared_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, user_header
          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq(
            "Unable to unshare domain from organization with name '#{shared_org1.name}'. Ensure the domain is shared to this organization.")
        end
      end
    end

    context 'when the org has routes using the domain' do
      let(:route_space) { VCAP::CloudController::Space.make(organization: shared_org1) }
      let(:route) { VCAP::CloudController::Route.make(domain: private_domain, space: route_space) }

      before do
        private_domain.add_shared_organization(shared_org1)
      end

      it 'returns a 422' do
        delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{route.space.organization_guid}", nil, user_header
        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq('This domain has associated routes in this organization. Delete the routes before unsharing.')
      end
    end

    context 'when user can write to source org but has no permissions in shared org' do
      before do
        org.add_manager(user)
        shared_org1.add_private_domain(private_domain)
      end

      it 'returns a 422' do
        delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, headers_for(user)
        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq("Organization with guid '#{shared_org1.guid}' does not exist or you do not have access to it.")
      end
    end

    describe 'when unsharing orgs for a private domain' do
      let(:api_call) { lambda { |user_headers| delete "/v3/domains/#{private_domain.guid}/relationships/shared_organizations/#{shared_org1.guid}", nil, user_headers } }
      let(:db_check) { lambda do
        domain = VCAP::CloudController::Domain.find(guid: private_domain.guid)
        expect(domain.shared_organizations).not_to include(shared_org1)
      end
      }

      before do
        private_domain.add_shared_organization(shared_org1)
      end

      context 'when the user is an org manager in the shared org' do
        before do
          shared_org1.add_manager(user)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 204,
          )

          h['admin_read_only'] = {
            code: 204
          }

          h['global_auditor'] = {
            code: 204
          }

          h.freeze
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the user is a billing manager is the shared org' do
        before do
          shared_org1.add_billing_manager(user)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
            response_object: { errors: [{ detail: "You do not have sufficient permissions for organization with guid '#{shared_org1.guid}' to unshare the domain." }] }
          )
          h['admin'] = {
            code: 204
          }
          h['org_manager'] = {
            code: 204
          }
          h['org_billing_manager'] = {
            code: 404
          }
          h['no_role'] = {
            code: 404
          }
          h.freeze
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end
    end
  end

  describe 'GET /v3/domains/:guid' do
    context 'when the domain does not exist' do
      let(:user_header) { headers_for(user) }

      it 'returns not found' do
        get '/v3/domains/does-not-exist', nil, user_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'when getting a shared domain' do
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

      let(:shared_domain_json) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{shared_domain.guid}/route_reservations) },
          }
        }
      end

      let(:api_call) { lambda { |user_headers| get "/v3/domains/#{shared_domain.guid}", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: shared_domain_json
        )
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when getting a private domain' do
      context 'when the domain has not been shared' do
        let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

        let(:private_domain_json) {
          {
            guid: private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: private_domain.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{private_domain.guid}/route_reservations) },
              shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{private_domain.guid}\/relationships\/shared_organizations) }
            }
          }
        }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: private_domain_json
          )
          h['org_billing_manager'] = {
            code: 404,
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{private_domain.guid}", nil, user_headers } }
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the domain has been shared with another organization' do
        let!(:non_visible_org) { VCAP::CloudController::Organization.make }
        let!(:user_visible_org) { VCAP::CloudController::Organization.make }

        let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

        before do
          non_visible_org.add_private_domain(private_domain)
          user_visible_org.add_private_domain(private_domain)
        end

        let(:private_domain_json) {
          {
            guid: private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: private_domain.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              },
              shared_organizations: {
                data: contain_exactly(*shared_organizations),
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{private_domain.guid}/route_reservations) },
              shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{private_domain.guid}\/relationships\/shared_organizations) }
            }
          }
        }

        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{private_domain.guid}", nil, user_headers } }

        context 'when the user can read in the shared organization' do
          let(:shared_organizations) { [{ guid: user_visible_org.guid }] }

          before do
            user_visible_org.add_manager(user)
          end

          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_object: private_domain_json
            ).freeze
          end

          it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
        end

        context 'when the user can read globally' do
          let(:shared_organizations) { [{ guid: non_visible_org.guid }, { guid: user_visible_org.guid }] }

          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_object: private_domain_json
            ).freeze
          end

          it_behaves_like 'permissions for single object endpoint', GLOBAL_SCOPES
        end
      end
    end
  end

  describe 'PATCH /v3/domains/:guid' do
    context 'when the domain does not exist' do
      let(:user_header) { headers_for(user) }

      it 'returns not found' do
        patch '/v3/domains/does-not-exist', nil, user_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'when metadata is invalid' do
      let(:domain) { VCAP::CloudController::SharedDomain.make }
      let(:user_header) { admin_headers_for(user) }

      it 'returns a 422' do
        patch "/v3/domains/#{domain.guid}", {
          metadata: {
            labels: { '': 'invalid' },
            annotations: { "#{'a' * 1001}": 'value2' }
          }
        }.to_json, user_header

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to match(/label [\w\s]+ error/)
      end
    end

    context 'updating an existing shared domain' do
      let(:domain) { VCAP::CloudController::SharedDomain.make }

      let(:domain_json) do
        {
          guid: domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{domain.guid}" },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain.guid}/route_reservations) },
          }
        }
      end

      let(:api_call) do
        lambda do |user_headers|
          patch "/v3/domains/#{domain.guid}", {
            metadata: {
              labels: { key: 'value' },
              annotations: { key2: 'value2' }
            }
          }.to_json, user_headers
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['admin'] = { code: 200, response_object: domain_json }

        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'updating an existing private domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

      let(:domain_json) do
        {
          guid: domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            shared_organizations: {
              data: []
            }
          },
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain.guid}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:api_call) do
        lambda do |user_headers|
          patch "/v3/domains/#{domain.guid}", {
            metadata: {
              labels: { key: 'value' },
              annotations: { key2: 'value2' }
            }
          }.to_json, user_headers
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['admin'] = { code: 200, response_object: domain_json }
        h['org_manager'] = { code: 200, response_object: domain_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'updating an existing, shared private domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make }

      let(:domain_json) do
        {
          guid: domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: domain.name,
          internal: false,
          router_group: nil,
          supported_protocols: ['http'],
          relationships: {
            organization: {
              data: { guid: domain.owning_organization_guid }
            },
            shared_organizations: {
              data: [{ guid: org.guid }]
            }
          },
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{domain.owning_organization_guid}) },
            route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain.guid}/route_reservations) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      let(:api_call) do
        lambda do |user_headers|
          patch "/v3/domains/#{domain.guid}", {
            metadata: {
              labels: { key: 'value' },
              annotations: { key2: 'value2' }
            }
          }.to_json, user_headers
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['admin'] = { code: 200, response_object: domain_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h.freeze
      end

      before do
        domain.add_shared_organization(org)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end
end
