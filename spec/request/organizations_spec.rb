require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'Organizations' do
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user) }
    let!(:organization1) { Organization.make name: 'Apocalypse World' }
    let!(:organization2) { Organization.make name: 'Dungeon World' }
    let!(:organization3) { Organization.make name: 'The Sprawl' }
    let!(:unaccesable_organization) { Organization.make name: 'D&D' }

    before do
      organization1.add_user(user)
      organization2.add_user(user)
      organization3.add_user(user)
      VCAP::CloudController::Domain.dataset.destroy # this will clean up the seeded test domains
    end

    describe 'POST /v3/organizations' do
      it 'creates a new organization with the given name' do
        request_body = {
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

        expect {
          post '/v3/organizations', request_body, admin_header
        }.to change {
          Organization.count
        }.by 1

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
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{created_org.guid}/domains/default" }
            },
            'relationships' => { 'quota' => { 'data' => { 'guid' => created_org.quota_definition.guid } } },
            'metadata' => {
              'labels' => { 'freaky' => 'friday' },
              'annotations' => { 'make' => 'subaru', 'model' => 'xv crosstrek', 'color' => 'orange' }
            }
          }
        )
      end
    end

    describe 'GET /v3/organizations' do
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
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
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
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains/default" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
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
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(orgB.guid, orgC.guid)
        end
      end
    end

    describe 'GET /v3/isolation_segments/:guid/organizations' do
      let(:isolation_segment1) { VCAP::CloudController::IsolationSegmentModel.make(name: 'awesome_seg') }
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

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
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization2.guid}/domains/default" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
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
                  'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization3.guid}/domains/default" }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
              }
            ]
          }
        )
      end
    end

    describe 'GET /v3/organizations/:guid/relationships/default_isolation_segment' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

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
            'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
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
      let!(:shared_domain) { VCAP::CloudController::SharedDomain.make(guid: 'shared-guid') }
      let!(:owned_private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization_guid: org.guid, guid: 'owned-private') }
      let!(:shared_private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization_guid: organization1.guid, guid: 'shared-private') }

      let(:shared_domain_json) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
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
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" }
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
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{owned_private_domain.guid}\/relationships\/shared_organizations) }
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
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{organization1.guid}) },
            shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{shared_private_domain.guid}\/relationships\/shared_organizations) }
          }
        }
      end

      before do
        org.add_private_domain(shared_private_domain)
      end

      context 'without filters' do
        let(:api_call) { lambda { |user_headers| get "/v3/organizations/#{org.guid}/domains", nil, user_headers } }
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              shared_domain_json,
              owned_private_domain_json,
              shared_private_domain_json,
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
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'when filtering by name' do
        let(:api_call) { lambda { |user_headers| get "/v3/organizations/#{org.guid}/domains?names=#{shared_domain.name}", nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              shared_domain_json,
            ]
          )
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'when filtering by organization_guid' do
        let(:api_call) { lambda { |user_headers| get "/v3/organizations/#{org.guid}/domains?organization_guids=#{org.guid}", nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              owned_private_domain_json,
            ]
          )
          h['org_billing_manager'] = {
            code: 200,
            response_objects: [],
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          get "/v3/organizations/#{organization1.guid}/domains"
          expect(last_response.status).to eq(401)
        end
      end

      describe 'when the org doesnt exist' do
        it 'returns 404 for Unauthenticated requests' do
          get '/v3/organizations/esdgth/domains', nil, user_header
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'GET /v3/organizations/:guid/domains/default' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:api_call) { lambda { |user_headers| get "/v3/organizations/#{org.guid}/domains/default", nil, user_headers } }

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
        let!(:internal_domain) { VCAP::CloudController::SharedDomain.make(internal: true) } # used to ensure internal domains do not get returned in any case
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: domain_json
          )
          h['no_role'] = { code: 404 }
          h.freeze
        end

        let(:shared_private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization_guid: organization1.guid) }
        let(:owned_private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization_guid: org.guid) }

        before do
          org.add_private_domain(shared_private_domain)
          owned_private_domain # trigger the let in order (after shared_private_domain)
        end

        context 'when at least one scoped domain exists' do
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: domain_json
            )
            h['org_billing_manager'] = { code: 404 }
            h['no_role'] = { code: 404 }
            h.freeze
          end

          let(:domain_json) do
            {
              guid: shared_private_domain.guid,
              created_at: iso8601,
              updated_at: iso8601,
              name: shared_private_domain.name,
              internal: false,
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
                self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}) },
                organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{organization1.guid}) },
                shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{shared_private_domain.guid}/relationships/shared_organizations) }
              }
            }
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end

        context 'when at least one non internal unscoped domain exists' do
          let!(:shared_domain) { VCAP::CloudController::SharedDomain.make }

          let(:domain_json) do
            {
              guid: shared_domain.guid,
              created_at: iso8601,
              updated_at: iso8601,
              name: shared_domain.name,
              internal: false,
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
                self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}) }
              }
            }
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      context 'when only internal domains exist' do
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404,
          )
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when no domains exist' do
        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404,
          )
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'PATCH /v3/organizations/:guid/relationships/default_isolation_segment' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
      let(:update_request) do
        {
          data: { guid: isolation_segment.guid }
        }.to_json
      end
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
        assigner.assign(isolation_segment, [organization1])
      end

      it 'updates the default isolation segment for the organization' do
        expect(organization1.default_isolation_segment_guid).to be_nil

        patch "/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'data' => {
            'guid' => isolation_segment.guid
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
            'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)

        organization1.reload
        expect(organization1.default_isolation_segment_guid).to eq(isolation_segment.guid)
      end
    end

    describe 'PATCH /v3/organizations/:guid' do
      let(:update_request) do
        {
          name: 'New Name World',
          metadata: {
            labels: {
              freaky: 'thursday'
            },
            annotations: {
              quality: 'p sus'
            }
          },
        }.to_json
      end

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
      end

      it 'updates the name for the organization' do
        patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'name' => 'New Name World',
          'guid' => organization1.guid,
          'relationships' => { 'quota' => { 'data' => { 'guid' => organization1.quota_definition.guid } } },
          'links' => {
            'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" },
            'domains' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains" },
            'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" }
          },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'metadata' => {
            'labels' => { 'freaky' => 'thursday' },
            'annotations' => { 'quality' => 'p sus' }
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)

        organization1.reload
        expect(organization1.name).to eq('New Name World')
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
            },
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
              'default_domain' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}/domains/default" }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => { 'animal' => 'horse' },
              'annotations' => {}
            }
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end
  end
end
