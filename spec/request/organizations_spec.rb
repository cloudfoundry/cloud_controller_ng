require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'Organizations' do
    let(:user) { User.make }
    let(:user_header) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user) }
    let!(:organization1) { Organization.make name: 'Apocalypse World' }
    let!(:organization2) { Organization.make name: 'Dungeon World' }
    let!(:organization3) { Organization.make name: 'The Sprawl' }
    let!(:inaccessible_organization) { Organization.make name: 'D&D' }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }

    before do
      organization1.add_user(user)
      organization2.add_user(user)
      organization3.add_user(user)
      Domain.dataset.destroy # this will clean up the seeded test domains
      TestConfig.override(kubernetes: {})

      allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
      allow(uaa_client).to receive(:usernames_for_ids).with([user.guid]).and_return(
        { user.guid => 'Ragnaros' }
      )
    end

    describe 'POST /v3/organizations' do
      let(:request_body) do
        {
          name: 'org1',
          metadata: {
            labels: {
              freaky: 'friday'
            },
            annotations: {
              make: 'subaru',
              model: 'xv crosstrek',
              color: 'orange'
            }
          }
        }.to_json
      end

      it 'creates a new organization with the given name' do
        expect do
          post '/v3/organizations', request_body, admin_header
        end.to change(Organization, :count).by 1

        created_org = Organization.last

        expect(last_response.status).to eq(201)

        expect(parsed_response).to be_a_response_like(
          {
            'guid' => created_org.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'name' => 'org1',
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/organizations/#{created_org.guid}" },
              'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains" },
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains/default" },
              'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{created_org.quota_definition.guid}" }
            },
            'relationships' => { 'quota' => { 'data' => { 'guid' => created_org.quota_definition.guid } } },
            'metadata' => {
              'labels' => { 'freaky' => 'friday' },
              'annotations' => { 'make' => 'subaru', 'model' => 'xv crosstrek', 'color' => 'orange' }
            },
            'suspended' => false
          }
        )
      end

      it 'allows creating a suspended org' do
        suspended_request_body = {
          name: 'suspended-org',
          suspended: true
        }.to_json

        post '/v3/organizations', suspended_request_body, admin_header
        expect(last_response.status).to eq(201)

        created_org = Organization.last

        expect(parsed_response).to be_a_response_like(
          {
            'guid' => created_org.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'name' => 'suspended-org',
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/organizations/#{created_org.guid}" },
              'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains" },
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains/default" },
              'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{created_org.quota_definition.guid}" }
            },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'relationships' => { 'quota' => { 'data' => { 'guid' => created_org.quota_definition.guid } } },
            'suspended' => true
          }
        )
      end

      context 'when "user_org_creation" feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'user_org_creation', enabled: true)
        end

        it 'lets ALL users create orgs' do
          expect do
            post '/v3/organizations', request_body, user_header
          end.to change(Organization, :count).by 1

          created_org = Organization.last

          expect(last_response.status).to eq(201)
          expect(parsed_response).to be_a_response_like(
            {
              'guid' => created_org.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'name' => 'org1',
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/organizations/#{created_org.guid}" },
                'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains" },
                'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains/default" },
                'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{created_org.quota_definition.guid}" }
              },
              'relationships' => { 'quota' => { 'data' => { 'guid' => created_org.quota_definition.guid } } },
              'metadata' => {
                'labels' => { 'freaky' => 'friday' },
                'annotations' => { 'make' => 'subaru', 'model' => 'xv crosstrek', 'color' => 'orange' }
              },
              'suspended' => false
            }
          )
        end

        it 'gives the user org manager and org user roles associated with the new org' do
          expect do
            post '/v3/organizations', request_body, user_header
          end.to change(Organization, :count).by 1

          created_org = Organization.last
          expect(OrganizationManager.first(organization_id: created_org.id, user_id: user.id)).to be_present
          expect(OrganizationUser.first(organization_id: created_org.id, user_id: user.id)).to be_present

          expect(created_org.users.count).to be(1)
          expect(created_org.managers.count).to be(1)
          expect(created_org.billing_managers.count).to be(0)
          expect(created_org.auditors.count).to be(0)
          expect(last_response.status).to eq(201)
        end
      end

      context 'when acting as an admin user' do
        it 'does not give the user any roles associated with the new org' do
          expect do
            post '/v3/organizations', request_body, admin_header
          end.to change(Organization, :count).by 1

          created_org = Organization.last
          expect(created_org.users.count).to be(0)
          expect(created_org.managers.count).to be(0)
          expect(created_org.billing_managers.count).to be(0)
          expect(created_org.auditors.count).to be(0)
          expect(last_response.status).to eq(201)
        end
      end
    end

    describe 'GET /v3/organizations' do
      describe 'query list parameters' do
        let(:isolation_segment1) { IsolationSegmentModel.make(name: 'seg') }
        let(:assigner) { IsolationSegmentAssign.new }

        before do
          assigner.assign(isolation_segment1, [organization1])
        end

        describe 'query list parameters' do
          it_behaves_like 'list query endpoint' do
            let(:message) { VCAP::CloudController::OrgsListMessage }
            let(:request) { '/v3/organizations' }
            let(:excluded_params) do
              [:isolation_segment_guid]
            end
            let(:params) do
              {
                guids: %w[foo bar],
                names: %w[foo bar],
                page: '2',
                per_page: '10',
                order_by: 'updated_at',
                label_selector: 'foo,bar',
                created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
                updated_ats: { gt: Time.now.utc.iso8601 }
              }
            end
          end
        end
      end

      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::Organization }
        let(:api_call) do
          ->(headers, filters) { get "/v3/organizations?#{filters}", nil, headers }
        end
        let(:headers) { admin_headers }
      end

      it 'returns a paginated list of orgs the user has access to' do
        get '/v3/organizations?per_page=2', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/organizations?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/organizations?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/organizations?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => organization1.guid,
                'name' => 'Apocalypse World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => { 'quota' => { 'data' => { 'guid' => organization1.quota_definition.guid } } },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}"
                  },
                  'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains" },
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" },
                  'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization1.quota_definition.guid}" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'suspended' => false
              },
              {
                'guid' => organization2.guid,
                'name' => 'Dungeon World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => { 'quota' => { 'data' => { 'guid' => organization2.quota_definition.guid } } },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                  },
                  'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains" },
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains/default" },
                  'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization2.quota_definition.guid}" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'suspended' => false
              }
            ]
          }
        )
      end

      context 'label_selector' do
        let!(:orgA) { Organization.make(name: 'A') }
        let!(:orgAFruit) { OrganizationLabelModel.make(key_name: 'fruit', value: 'strawberry', organization: orgA) }
        let!(:orgAAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: orgA) }

        let!(:orgB) { Organization.make(name: 'B') }
        let!(:orgBEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgB) }
        let!(:orgBAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'dog', organization: orgB) }

        let!(:orgC) { Organization.make(name: 'C') }
        let!(:orgCEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgC) }
        let!(:orgCAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: orgC) }

        let!(:orgD) { Organization.make(name: 'D') }
        let!(:orgDEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgD) }

        let!(:orgE) { Organization.make(name: 'E') }
        let!(:orgEEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'staging', organization: orgE) }
        let!(:orgEAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'dog', organization: orgE) }

        it 'returns the matching orgs' do
          get '/v3/organizations?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_header
          expect(last_response.status).to eq(200), last_response.body

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(orgB.guid, orgC.guid)
        end
      end

      context 'permissions' do
        before do
          organization1.remove_user(user)
          organization2.remove_user(user)
          organization3.remove_user(user)
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS do
          let(:api_call) { ->(user_headers) { get 'v3/organizations', nil, user_headers } }
          let(:space) { VCAP::CloudController::Space.make }
          let(:org) { space.organization }
          let(:expected_codes_and_responses) do
            h = Hash.new(code: 200, response_guids: [org.guid])
            h['admin'] = { code: 200, response_guids: VCAP::CloudController::Organization.select_map(:guid) }
            h['admin_read_only'] = { code: 200, response_guids: VCAP::CloudController::Organization.select_map(:guid) }
            h['global_auditor'] = { code: 200, response_guids: VCAP::CloudController::Organization.select_map(:guid) }
            h['no_role'] = { code: 200, response_guids: [] }
            h
          end
        end
      end
    end

    describe 'GET /v3/isolation_segments/:guid/organizations' do
      let(:isolation_segment1) { IsolationSegmentModel.make(name: 'awesome_seg') }
      let(:assigner) { IsolationSegmentAssign.new }

      before do
        assigner.assign(isolation_segment1, [organization2, organization3])
      end

      it 'returns a paginated list of orgs entitled to the isolation segment' do
        get "/v3/isolation_segments/#{isolation_segment1.guid}/organizations?per_page=2", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => organization2.guid,
                'name' => 'Dungeon World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => { 'quota' => { 'data' => { 'guid' => organization2.quota_definition.guid } } },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                  },
                  'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains" },
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains/default" },
                  'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization2.quota_definition.guid}" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'suspended' => false
              },
              {
                'guid' => organization3.guid,
                'name' => 'The Sprawl',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => { 'quota' => { 'data' => { 'guid' => organization3.quota_definition.guid } } },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization3.guid}"
                  },
                  'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization3.guid}/domains" },
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization3.guid}/domains/default" },
                  'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization3.quota_definition.guid}" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'suspended' => false
              }
            ]
          }
        )
      end
    end

    describe 'GET /v3/organizations/:guid/relationships/default_isolation_segment' do
      let(:isolation_segment) { IsolationSegmentModel.make(name: 'default_seg') }
      let(:assigner) { IsolationSegmentAssign.new }

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
        assigner.assign(isolation_segment, [organization1])
        organization1.update(default_isolation_segment_guid: isolation_segment.guid)
      end

      it 'shows the default isolation segment for the organization' do
        get "/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment", nil, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'data' => {
            'guid' => isolation_segment.guid
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
            'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" }
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    describe 'GET /v3/organizations/:guid/domains' do
      let(:space) { Space.make }
      let(:org) { space.organization }

      describe 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          get "/v3/organizations/#{organization1.guid}/domains"
          expect(last_response.status).to eq(401)
        end
      end

      describe 'when the user is logged in' do
        let!(:shared_domain) { SharedDomain.make(guid: 'shared-guid') }
        let!(:owned_private_domain) { PrivateDomain.make(owning_organization_guid: org.guid, guid: 'owned-private') }
        let!(:shared_private_domain) { PrivateDomain.make(owning_organization_guid: organization1.guid, guid: 'shared-private') }

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
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{shared_domain.guid}/route_reservations} }
            }
          }
        end
        let(:owned_private_domain_json) do
          {
            guid: owned_private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: owned_private_domain.name,
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
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{owned_private_domain.guid}" },
              organization: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{org.guid}} },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{owned_private_domain.guid}/route_reservations} },
              shared_organizations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{owned_private_domain.guid}/relationships/shared_organizations} }
            }
          }
        end
        let(:shared_private_domain_json) do
          {
            guid: shared_private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: shared_private_domain.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: { guid: organization1.guid }
              },
              shared_organizations: {
                data: [{ guid: org.guid }]
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{shared_private_domain.guid}" },
              organization: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{organization1.guid}} },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{shared_private_domain.guid}/route_reservations} },
              shared_organizations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{shared_private_domain.guid}/relationships/shared_organizations} }
            }
          }
        end

        before do
          org.add_private_domain(shared_private_domain)
        end

        describe "when the org doesn't exist" do
          it 'returns 404 for Unauthenticated requests' do
            get '/v3/organizations/esdgth/domains', nil, user_header
            expect(last_response.status).to eq(404)
          end
        end

        context 'without filters' do
          let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/domains", nil, user_headers } }
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                shared_domain_json,
                owned_private_domain_json,
                shared_private_domain_json
              ]
            )
            h['org_billing_manager'] = {
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            }
            h['no_role'] = {
              code: 404,
              response_objects: []
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
        end

        describe 'when filtering by name' do
          let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/domains?names=#{shared_domain.name}", nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            )
            h['no_role'] = {
              code: 404
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
        end

        describe 'when filtering by guid' do
          let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/domains?guids=#{shared_domain.guid}", nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            )
            h['no_role'] = {
              code: 404
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
        end

        describe 'when filtering by organization_guid' do
          let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/domains?organization_guids=#{org.guid}", nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                owned_private_domain_json
              ]
            )
            h['org_billing_manager'] = {
              code: 200,
              response_objects: []
            }
            h['no_role'] = {
              code: 404
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
        end
      end

      describe 'when filtering by labels' do
        let!(:domain1) { PrivateDomain.make(name: 'dom1.com', owning_organization: org) }
        let!(:domain1_label) { DomainLabelModel.make(resource_guid: domain1.guid, key_name: 'animal', value: 'dog') }

        let!(:domain2) { PrivateDomain.make(name: 'dom2.com', owning_organization: org) }
        let!(:domain2_label) { DomainLabelModel.make(resource_guid: domain2.guid, key_name: 'animal', value: 'cow') }
        let!(:domain2__exclusive_label) { DomainLabelModel.make(resource_guid: domain2.guid, key_name: 'santa', value: 'claus') }

        let(:base_link) { "/v3/organizations/#{org.guid}/domains" }
        let(:base_pagination_link) { "#{link_prefix}#{base_link}" }

        let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

        it 'returns a 200 and the filtered apps for "in" label selector' do
          get "#{base_link}?label_selector=animal in (dog)", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for "notin" label selector' do
          get "#{base_link}?label_selector=animal notin (dog)", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain2.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for "=" label selector' do
          get "#{base_link}?label_selector=animal=dog", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal%3Ddog&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal%3Ddog&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for "==" label selector' do
          get "#{base_link}?label_selector=animal==dog", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for "!=" label selector' do
          get "#{base_link}?label_selector=animal!=dog", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal%21%3Ddog&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal%21%3Ddog&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain2.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for "=" label selector' do
          get "#{base_link}?label_selector=animal=cow,santa=claus", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain2.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for existence label selector' do
          get "#{base_link}?label_selector=santa", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=santa&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=santa&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain2.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered domains for non-existence label selector' do
          get "#{base_link}?label_selector=!santa", nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{base_pagination_link}?label_selector=%21santa&page=1&per_page=50" },
            'last' => { 'href' => "#{base_pagination_link}?label_selector=%21santa&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(domain1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 400 when the label selector is missing a value' do
          get "#{base_link}?label_selector", nil, admin_header
          expect(last_response.status).to eq(400)
          expect(parsed_response['errors'].first['detail']).to match(/Missing label_selector value/)
        end

        it "returns a 400 when the label selector's value is invalid" do
          get "#{base_link}?label_selector=!", nil, admin_header
          expect(last_response.status).to eq(400)
          expect(parsed_response['errors'].first['detail']).to match(/Invalid label_selector value/)
        end
      end
    end

    describe 'GET /v3/organizations/:guid/domains/default' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/domains/default", nil, user_headers } }

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          get "/v3/organizations/#{org.guid}/domains/default", nil, base_json_headers
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the user does not have the required scopes' do
        let(:user_header) { headers_for(user, scopes: []) }

        it 'returns a 403' do
          get "/v3/organizations/#{org.guid}/domains/default", nil, user_header
          expect(last_response.status).to eq(403)
        end
      end

      context 'when domains exist' do
        let!(:internal_domain) { SharedDomain.make(internal: true) } # used to ensure internal domains do not get returned in any case
        let!(:tcp_domain) { SharedDomain.make(router_group_guid: 'default-tcp') }
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: domain_json
          )
          h['no_role'] = { code: 404 }
          h
        end

        let(:shared_private_domain) { PrivateDomain.make(owning_organization_guid: organization1.guid) }
        let(:owned_private_domain) { PrivateDomain.make(owning_organization_guid: org.guid) }

        before do
          org.add_private_domain(shared_private_domain)
          owned_private_domain # trigger the let in order (after shared_private_domain)
        end

        context 'when at least one private domain exists' do
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: domain_json
            )
            h['org_billing_manager'] = { code: 404 }
            h['no_role'] = { code: 404 }
            h
          end

          let(:domain_json) do
            {
              guid: shared_private_domain.guid,
              created_at: iso8601,
              updated_at: iso8601,
              name: shared_private_domain.name,
              internal: false,
              router_group: nil,
              supported_protocols: ['http'],
              metadata: {
                labels: {},
                annotations: {}
              },
              relationships: {
                organization: {
                  data: { guid: organization1.guid }
                },
                shared_organizations: {
                  data: [
                    { guid: org.guid }
                  ]
                }
              },
              links: {
                self: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{UUID_REGEX}} },
                organization: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{organization1.guid}} },
                route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{shared_private_domain.guid}/route_reservations} },
                shared_organizations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{shared_private_domain.guid}/relationships/shared_organizations} }
              }
            }
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end

        context 'when at least one non-internal shared domain exists' do
          let!(:shared_domain) { SharedDomain.make }

          let(:domain_json) do
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
                self: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{UUID_REGEX}} },
                route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{UUID_REGEX}/route_reservations} }
              }
            }
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      context 'when only internal domains exist' do
        let!(:internal_domain) { SharedDomain.make(internal: true) } # used to ensure internal domains do not get returned in any case

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404
          )
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when only tcp domains exist' do
        let!(:tcp_domain) { SharedDomain.make(router_group_guid: 'default-tcp') }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404
          )
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when no domains exist' do
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404
          )
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'GET /v3/organizations/:guid/usage_summary' do
      let!(:org) { Organization.make }
      let!(:space) { Space.make(organization: org) }
      let!(:app1) { AppModel.make(space:) }
      let!(:app2) { AppModel.make(space:) }
      let!(:process1) { ProcessModel.make(:process, state: 'STARTED', app: app1, type: 'web', memory: 101) }
      let!(:process2) { ProcessModel.make(:process, state: 'STARTED', app: app1, type: 'web', memory: 102, instances: 2) }

      before do
        ProcessModelFactory.make(space: space, memory: 200, instances: 2, state: 'STARTED', type: 'worker')
      end

      let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/usage_summary", nil, user_headers } }

      let(:org_summary_json) do
        {
          usage_summary: {
            started_instances: 5,
            memory_in_mb: 705, # (tasks: 200 * 2) + (processes: 101 + 2 * 102)
            total_routes: 0,
            total_service_instances: 0,
            total_reserved_ports: 0,
            total_domains: 0,
            per_app_tasks: 0,
            total_service_keys: 0
          },
          links: {
            self: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{org.guid}/usage_summary} },
            organization: { href: %r{#{Regexp.escape(link_prefix)}/v3/organizations/#{org.guid}} }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: org_summary_json
        )
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the org does not exist' do
        it 'returns a 404' do
          get '/v3/organizations/bad-guid/usage_summary', {}, admin_header
          expect(last_response).to have_status_code(404)
        end
      end

      context 'when the user cannot read from the org' do
        let(:user) { set_current_user(VCAP::CloudController::User.make) }

        before do
          stub_readable_org_guids_for(user, [])
        end

        it 'returns a 404' do
          get '/v3/organizations/bad-guid/usage_summary', {}, headers_for(user)
          expect(last_response).to have_status_code(404)
        end
      end
    end

    describe 'PATCH /v3/organizations/:guid/relationships/default_isolation_segment' do
      context 'as admin' do
        let(:isolation_segment) { IsolationSegmentModel.make(name: 'default_seg') }
        let(:update_request) do
          {
            data: { guid: isolation_segment.guid }
          }.to_json
        end
        let(:assigner) { IsolationSegmentAssign.new }

        before do
          set_current_user(user, { admin: true })
          allow_user_read_access_for(user, orgs: [organization1])
          assigner.assign(isolation_segment, [organization1])
        end

        it 'updates the default isolation segment for the organization' do
          expect(organization1.default_isolation_segment_guid).to be_nil

          patch "/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment", update_request,
                admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

          expected_response = {
            'data' => {
              'guid' => isolation_segment.guid
            },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
              'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" }
            }
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)

          organization1.reload
          expect(organization1.default_isolation_segment_guid).to eq(isolation_segment.guid)
        end
      end

      context 'when organization is suspended' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:api_call) { ->(user_headers) { patch "/v3/organizations/#{org.guid}/relationships/default_isolation_segment", nil, user_headers } }
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
          h['admin'] = { code: 200 }
          h['org_manager'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h['no_role'] = { code: 404 }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'GET /v3/organizations/:guid' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }
      let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}", nil, user_headers } }
      let(:expected_response_object) do
        {
          'guid' => org.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org.name.to_s,
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{org.guid}" },
            'domains' => { 'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains" },
            'default_domain' => { 'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains/default" },
            'quota' => { 'href' => "#{link_prefix}/v3/organization_quotas/#{org.quota_definition.guid}" }
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org.quota_definition.guid } } },
          'metadata' => {
            'labels' => {},
            'annotations' => {}
          },
          'suspended' => false
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_object: expected_response_object)
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
          expected_response_object['suspended'] = true
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'PATCH /v3/organizations/:guid' do
      context 'as admin' do
        before do
          set_current_user(user, { admin: true })
          allow_user_read_access_for(user, orgs: [organization1])
        end

        it 'updates the name for the organization' do
          update_request = {
            name: 'New Name World',
            metadata: {
              labels: {
                freaky: 'thursday'
              },
              annotations: {
                quality: 'p sus'
              }
            }
          }.to_json

          patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

          expected_response = {
            'name' => 'New Name World',
            'guid' => organization1.guid,
            'relationships' => { 'quota' => { 'data' => { 'guid' => organization1.quota_definition.guid } } },
            'links' => {
              'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" },
              'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains" },
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" },
              'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization1.quota_definition.guid}" }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => { 'freaky' => 'thursday' },
              'annotations' => { 'quality' => 'p sus' }
            },
            'suspended' => false
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)

          organization1.reload
          expect(organization1.name).to eq('New Name World')
        end

        context 'when the new name is already taken' do
          before do
            Organization.make(name: 'new-name')
          end

          it 'returns a 422 with a helpful error message' do
            update_request = { name: 'new-name' }.to_json

            expect do
              patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')
            end.not_to(change { organization1.reload.name })

            expect(last_response.status).to eq(422)
            expect(last_response).to have_error_message("Organization name 'new-name' is already taken.")
          end
        end

        it 'updates the suspended field for the organization' do
          update_request = {
            name: 'New Name World',
            suspended: true
          }.to_json

          patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

          expected_response = {
            'name' => 'New Name World',
            'guid' => organization1.guid,
            'relationships' => { 'quota' => { 'data' => { 'guid' => organization1.quota_definition.guid } } },
            'links' => {
              'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" },
              'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains" },
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" },
              'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization1.quota_definition.guid}" }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'suspended' => true
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)

          organization1.reload
          expect(organization1.name).to eq('New Name World')
          expect(organization1).to be_suspended
        end

        context 'deleting labels' do
          let!(:org1Fruit) { OrganizationLabelModel.make(key_name: 'fruit', value: 'strawberry', organization: organization1) }
          let!(:org1Animal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: organization1) }
          let(:update_request) do
            {
              metadata: {
                labels: {
                  fruit: nil
                }
              }
            }.to_json
          end

          it 'updates the label metadata' do
            patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

            expected_response = {
              'name' => organization1.name,
              'guid' => organization1.guid,
              'relationships' => { 'quota' => { 'data' => { 'guid' => organization1.quota_definition.guid } } },
              'links' => {
                'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" },
                'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains" },
                'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" },
                'quota' => { 'href' => "http://api2.vcap.me/v3/organization_quotas/#{organization1.quota_definition.guid}" }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'metadata' => {
                'labels' => { 'animal' => 'horse' },
                'annotations' => {}
              },
              'suspended' => false
            }

            parsed_response = MultiJson.load(last_response.body)

            expect(last_response.status).to eq(200)
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end
      end

      context 'when organization is suspended' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:api_call) { ->(user_headers) { patch "/v3/organizations/#{org.guid}", nil, user_headers } }
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
          h['admin'] = { code: 200 }
          h['org_manager'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h['no_role'] = { code: 404 }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'DELETE /v3/organizations/:guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:associated_user) { User.make(default_space: space) }
      let(:shared_service_instance) do
        s = ServiceInstance.make
        s.add_shared_space(space)
        s
      end

      before do
        AppModel.make(space:)
        Route.make(space:)
        org.add_user(associated_user)
        space.add_developer(associated_user)
        ServiceInstance.make(space:)
        ServiceBroker.make(space:)
      end

      let(:db_check) do
        lambda do
          expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})

          execute_all_jobs(expected_successes: 2, expected_failures: 0)
          last_job = VCAP::CloudController::PollableJobModel.last
          expect(last_response.headers['Location']).to match(%r{/v3/jobs/#{last_job.guid}})
          expect(last_job.resource_type).to eq('organization')

          get "/v3/organizations/#{org.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end
      let(:api_call) { ->(user_headers) { delete "/v3/organizations/#{org.guid}", nil, user_headers } }

      it 'destroys the requested organization and sub resources (spaces)' do
        expect do
          delete "/v3/organizations/#{org.guid}", nil, admin_header
          expect(last_response.status).to eq(202)
          expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})

          execute_all_jobs(expected_successes: 2, expected_failures: 0)
          get "/v3/organizations/#{org.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
          get "/v3/spaces/#{space.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
        end.to change(Organization, :count).by(-1).
          and change(Space, :count).by(-1).
          and change(AppModel, :count).by(-1).
          and change(Route, :count).by(-1).
          and change { associated_user.reload.default_space }.to(be_nil).
          and change { associated_user.reload.spaces }.to(be_empty).
          and change(ServiceInstance, :count).by(-1).
          and change(ServiceBroker, :count).by(-1).
          and change { shared_service_instance.reload.shared_spaces }.to(be_empty)
      end

      context 'deleting metadata' do
        it_behaves_like 'resource with metadata' do
          let(:resource) { org }
          let(:api_call) do
            -> { delete "/v3/organizations/#{org.guid}", nil, admin_header }
          end
        end
      end

      context 'when the user is a member in the org' do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 202 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      describe 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          delete "/v3/organizations/#{org.guid}", nil, base_json_headers
          expect(last_response.status).to eq(401)
        end
      end

      describe 'when there is a shared private domain' do
        let!(:shared_private_domain) { PrivateDomain.make(owning_organization_guid: org.guid, guid: 'shared-private', shared_organization_guids: [organization1.guid]) }

        it 'returns a 202' do
          delete "/v3/organizations/#{org.guid}", nil, admin_headers
          expect(last_response.status).to eq(202)
          expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})

          # ::OrganizationDelete should fail and ::V3::BuildpackCacheDelete should succeed
          execute_all_jobs(expected_successes: 1, expected_failures: 1)

          job_url = last_response.headers['Location']
          get job_url, {}, admin_headers
          expect(last_response.status).to eq(200)

          expect(parsed_response['state']).to eq('FAILED')
          expect(parsed_response['errors'].size).to eq(1)
          expect(parsed_response['errors'].first['detail']).to eq(
            "Deletion of organization #{org.name} failed because one or more resources " \
            "within could not be deleted.\n\nDomain '#{shared_private_domain.name}' is " \
            'shared with other organizations. Unshare before deleting.'
          )
        end
      end
    end

    describe 'GET /v3/organizations/:guid/users' do
      let(:other_org_user) { VCAP::CloudController::User.make(guid: 'other-org-user') }
      let(:org_manager) { VCAP::CloudController::User.make(guid: 'org-manager') }

      before do
        allow(VCAP::CloudController::UaaClient).to receive(:new).and_return(uaa_client)

        organization1.add_manager(org_manager)
        organization2.add_user(other_org_user)

        allow(uaa_client).to receive(:users_for_ids).with(contain_exactly(user.guid, org_manager.guid)).and_return({
                                                                                                                     user.guid => { 'username' => 'bob-mcjames',
                                                                                                                                    'origin' => 'Okta' },
                                                                                                                     org_manager.guid => { 'username' => 'rob-mcjames',
                                                                                                                                           'origin' => 'Okta' }
                                                                                                                   })
        allow(uaa_client).to receive(:users_for_ids).with([]).and_return({})
      end

      context 'filters' do
        before do
          allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return({
                                                                                      user.guid => { 'username' => 'bob-mcjames', 'origin' => 'Okta' }
                                                                                    })
        end

        it_behaves_like 'list query endpoint' do
          before do
            allow(uaa_client).to receive(:ids_for_usernames_and_origins).and_return([])
          end

          let(:excluded_params) { [:partial_usernames] }
          let(:request) { "/v3/organizations/#{organization1.guid}/users" }
          let(:message) { VCAP::CloudController::UsersListMessage }
          let(:user_header) { admin_header }

          let(:params) do
            {
              guids: %w[foo bar],
              usernames: %w[foo bar],
              origins: %w[foo bar],
              page: '2',
              per_page: '10',
              order_by: 'updated_at',
              label_selector: 'foo,bar',
              created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
              updated_ats: { gt: Time.now.utc.iso8601 }
            }
          end
        end

        context 'uses partial_usernames' do
          it_behaves_like 'list query endpoint' do
            before do
              allow(uaa_client).to receive(:ids_for_usernames_and_origins).and_return([])
            end

            let(:excluded_params) { [:usernames] }
            let(:request) { "/v3/organizations/#{organization1.guid}/users" }
            let(:message) { VCAP::CloudController::UsersListMessage }
            let(:user_header) { admin_header }

            let(:params) do
              {
                guids: %w[foo bar],
                partial_usernames: %w[foo bar],
                origins: %w[foo bar],
                page: '2',
                per_page: '10',
                order_by: 'updated_at',
                label_selector: 'foo,bar',
                created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
                updated_ats: { gt: Time.now.utc.iso8601 }
              }
            end
          end
        end

        context 'by guid' do
          it 'returns 200 and the filtered users' do
            get "/v3/organizations/#{organization1.guid}/users?guids=#{user.guid}", nil, admin_header

            parsed_response = MultiJson.load(last_response.body)
            expected_pagination = {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?guids=#{user.guid}&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?guids=#{user.guid}&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil
            }

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(user.guid)
            expect(parsed_response['pagination']).to eq(expected_pagination)
          end
        end

        context 'by usernames and origins' do
          before do
            allow(uaa_client).to receive(:users_for_ids).with([org_manager.guid]).and_return({
                                                                                               org_manager.guid => { 'username' => 'rob-mcjames', 'origin' => 'Okta' }
                                                                                             })
            allow(uaa_client).to receive(:ids_for_usernames_and_origins).with(['rob-mcjames'], ['Okta']).and_return([org_manager.guid])
          end

          it 'returns 200 and the filtered users' do
            get "/v3/organizations/#{organization1.guid}/users?usernames=rob-mcjames&origins=Okta", nil, admin_header

            parsed_response = MultiJson.load(last_response.body)
            expected_pagination = {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?origins=Okta&page=1&per_page=50&usernames=rob-mcjames" },
              'last' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?origins=Okta&page=1&per_page=50&usernames=rob-mcjames" },
              'next' => nil,
              'previous' => nil
            }

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(org_manager.guid)
            expect(parsed_response['pagination']).to eq(expected_pagination)
          end
        end

        context 'by partial_usernames and origins' do
          before do
            allow(uaa_client).to receive(:users_for_ids).with([org_manager.guid]).and_return({
                                                                                               org_manager.guid => { 'username' => 'rob-mcjam', 'origin' => 'Okta' }
                                                                                             })
            allow(uaa_client).to receive(:ids_for_usernames_and_origins).with(['b-mcjam'], ['Okta'], false).and_return([org_manager.guid])
          end

          it 'returns 200 and the filtered users' do
            get "/v3/organizations/#{organization1.guid}/users?partial_usernames=b-mcjam&origins=Okta", nil, admin_header

            parsed_response = MultiJson.load(last_response.body)
            expected_pagination = {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?origins=Okta&page=1&partial_usernames=b-mcjam&per_page=50" },
              'last' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?origins=Okta&page=1&partial_usernames=b-mcjam&per_page=50" },
              'next' => nil,
              'previous' => nil
            }

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(org_manager.guid)
            expect(parsed_response['pagination']).to eq(expected_pagination)
          end
        end

        context 'by labels' do
          let!(:user_label) { VCAP::CloudController::UserLabelModel.make(resource_guid: user.guid, key_name: 'animal', value: 'dog') }

          it 'returns a 200 and the filtered users for "in" label selector' do
            get "/v3/organizations/#{organization1.guid}/users?label_selector=animal in (dog)", nil, admin_header
            expect(last_response).to have_status_code(200)

            parsed_response = MultiJson.load(last_response.body)
            expected_pagination = {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/users?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil
            }
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(user.guid)
            expect(parsed_response['pagination']).to eq(expected_pagination)
          end
        end

        # normally this would be under request_spec_shared_examples; we copy it here because this test brings up issues with UAA
        context 'by timestamps on creation' do
          let!(:resource_1) { VCAP::CloudController::User.make(guid: '1', created_at: '2020-05-26T18:47:01Z') }
          let!(:resource_2) { VCAP::CloudController::User.make(guid: '2', created_at: '2020-05-26T18:47:02Z') }
          let!(:resource_3) { VCAP::CloudController::User.make(guid: '3', created_at: '2020-05-26T18:47:03Z') }
          let!(:resource_4) { VCAP::CloudController::User.make(guid: '4', created_at: '2020-05-26T18:47:04Z') }

          before do
            organization1.add_user(resource_1)
            organization1.add_user(resource_4)
            allow(uaa_client).to receive(:users_for_ids).and_return({})
          end

          it 'returns 200 and filters' do
            get "/v3/organizations/#{organization1.guid}/users?created_ats[lt]=#{resource_3.created_at.iso8601}", nil, admin_headers

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid)
          end
        end

        # normally this would be under request_spec_shared_examples; we copy it here because this test brings up issues with UAA
        context 'by timestamps on update' do
          # before must occur before the let! otherwise the resources will be created with
          # update_on_create: true
          before do
            VCAP::CloudController::User.plugin :timestamps, update_on_create: false
            allow(uaa_client).to receive(:users_for_ids).and_return({})
          end

          let!(:resource_1) { VCAP::CloudController::User.make(guid: '1', updated_at: '2020-05-26T18:47:01Z') }
          let!(:resource_2) { VCAP::CloudController::User.make(guid: '2', updated_at: '2020-05-26T18:47:02Z') }
          let!(:resource_3) { VCAP::CloudController::User.make(guid: '3', updated_at: '2020-05-26T18:47:03Z') }
          let!(:resource_4) { VCAP::CloudController::User.make(guid: '4', updated_at: '2020-05-26T18:47:04Z') }

          after do
            VCAP::CloudController::User.plugin :timestamps, update_on_create: true
          end

          it 'returns 200 and filters' do
            organization1.add_user(resource_1)
            organization1.add_user(resource_4)
            get "/v3/organizations/#{organization1.guid}/users?updated_ats[lt]=#{resource_3.updated_at.iso8601}", nil, admin_headers

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid)
          end
        end
      end

      context 'no filters' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:api_call) { ->(user_headers) { get "/v3/organizations/#{org.guid}/users", nil, user_headers } }
        let(:user_json) { build_user_json(user.guid, 'bob-mcjames', 'Okta') }
        let(:org_manager_json) { build_user_json(org_manager.guid, 'rob-mcjames', 'Okta') }
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              user_json,
              org_manager_json
            ]
          )
          h['no_role'] = {
            code: 404
          }
          %w[
            admin
            admin_read_only
            global_auditor
          ].each do |role|
            h[role] = {
              code: 200,
              response_objects: [
                org_manager_json
              ]
            }
          end

          h
        end

        before do
          org.add_manager(org_manager)
          allow(uaa_client).to receive(:users_for_ids).with([org_manager.guid]).and_return({
                                                                                             org_manager.guid => { 'username' => 'rob-mcjames', 'origin' => 'Okta' }
                                                                                           })
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:users_for_ids).and_raise(VCAP::CloudController::UaaUnavailable)
        end

        it 'returns an error indicating UAA is unavailable' do
          get "/v3/organizations/#{organization1.guid}/users", nil, admin_header
          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors'].first['detail']).to eq('The UAA service is currently unavailable')
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          get "/v3/organizations/#{organization1.guid}/users", nil, base_json_headers
          expect(last_response).to have_status_code(401)
        end
      end
    end
  end

  def build_user_json(guid, username, origin)
    {
      guid: guid,
      created_at: iso8601,
      updated_at: iso8601,
      username: username,
      presentation_name: (username.presence || guid),
      origin: origin,
      metadata: {
        labels: {},
        annotations: {}
      },
      links: {
        self: { href: %r{#{Regexp.escape(link_prefix)}/v3/users/#{guid}} }
      }
    }
  end
end
