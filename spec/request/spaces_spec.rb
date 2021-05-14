require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Spaces' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make name: 'Boardgames', created_at: 2.days.ago }
  let!(:space1) { VCAP::CloudController::Space.make name: 'Catan', organization: org }
  let!(:space2) { VCAP::CloudController::Space.make name: 'Ticket to Ride', organization: org }
  let!(:space3) { VCAP::CloudController::Space.make name: 'Agricola', organization: org }

  before do
    org.add_user(user)
    space1.add_developer(user)
    space2.add_developer(user)
    space3.add_developer(user)
    TestConfig.override(kubernetes: {})
  end

  describe 'POST /v3/spaces' do
    it 'creates a new space with the given name and org' do
      request_body = {
        name: 'space1',
        relationships: {
          organization: {
            data: { guid: org.guid }
          }
        },
        metadata: {
          labels: {
            hocus: 'pocus'
          },
          annotations: {
            boo: 'urns'
          }
        }
      }.to_json

      expect {
        post '/v3/spaces', request_body, admin_header
      }.to change {
        VCAP::CloudController::Space.count
      }.by 1

      created_space = VCAP::CloudController::Space.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'guid' => created_space.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => 'space1',
          'relationships' => {
            'organization' => {
              'data' => { 'guid' => created_space.organization_guid }
            },
            'quota' => {
              'data' => nil
            }
          },
          'links' => build_space_links(created_space),
          'metadata' => {
            'labels' => { 'hocus' => 'pocus' },
            'annotations' => { 'boo' => 'urns' },
          }
        }
      )
    end

    context 'when a relationships hash is not provided' do
      it 'returns a 422 error' do
        request_body = {
          name: 'space1'
        }.to_json

        post '/v3/spaces', request_body, admin_header
        expect(last_response.status).to eq(422)
      end
    end
  end

  describe 'GET /v3/spaces/:guid' do
    it 'returns the requested space' do
      get "/v3/spaces/#{space1.guid}", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'guid' => space1.guid,
          'name' => 'Catan',
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'relationships' => {
            'organization' => {
              'data' => { 'guid' => space1.organization_guid }
            },
            'quota' => {
              'data' => nil
            }
          },
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => build_space_links(space1),
        }
      )
    end

    it 'returns the requested space including org info' do
      get "/v3/spaces/#{space1.guid}?include=organization", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      orgs = parsed_response['included']['organizations']

      expect(orgs).to be_present
      expect(orgs[0]).to be_a_response_like(
        {
          'guid' => org.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org.name,
          'suspended' => false,
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}",
            },
            'default_domain' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains/default",
            },
            'domains' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains",
            },
            'quota' => {
              'href' => "#{link_prefix}/v3/organization_quotas/#{org.quota_definition.guid}"
            }
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org.quota_definition.guid } } },
        }
      )
    end

    context 'when the space has a quota applied to it' do
      let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: space1.organization) }

      before do
        space_quota.add_space(space1)
      end

      it 'returns the requested space including quota relationship and link' do
        get "/v3/spaces/#{space1.guid}", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'guid' => space1.guid,
            'name' => 'Catan',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => {
              'organization' => {
                'data' => { 'guid' => space1.organization_guid }
              },
              'quota' => {
                'data' => { 'guid' => space_quota.guid }
              }
            },
            'metadata' => {
              'labels' => {},
              'annotations' => {},
            },
            'links' => build_space_links(space1).merge({
              'quota' => {
                'href' => "#{link_prefix}/v3/space_quotas/#{space_quota.guid}"
              }
            }),
          }
        )
      end
    end
  end

  describe 'GET /v3/spaces' do
    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/spaces' }
      let(:message) { VCAP::CloudController::SpacesListMessage }

      let(:params) do
        {
          names: ['foo', 'bar'],
          organization_guids: ['foo', 'bar'],
          guids: ['foo', 'bar'],
          include: 'org',
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    context 'when a label_selector is not provided' do
      it 'returns a paginated list of spaces the user has access to' do
        get '/v3/spaces?per_page=2', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/spaces?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/spaces?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/spaces?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => space1.guid,
                'name' => 'Catan',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => {
                  'organization' => {
                    'data' => { 'guid' => space1.organization_guid }
                  },
                  'quota' => {
                    'data' => nil
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {},
                },
                'links' => build_space_links(space1)
              },
              {
                'guid' => space2.guid,
                'name' => 'Ticket to Ride',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => {
                  'organization' => {
                    'data' => { 'guid' => space2.organization_guid }
                  },
                  'quota' => {
                    'data' => nil
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {},
                },
                'links' => build_space_links(space2)
              }
            ]
          }
        )
      end
    end

    context 'when a label_selector is provided' do
      let!(:spaceA) { VCAP::CloudController::Space.make(organization: org) }
      let!(:spaceAFruit) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'fruit', value: 'strawberry', space: spaceA) }
      let!(:spaceAAnimal) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'horse', space: spaceA) }

      let!(:spaceB) { VCAP::CloudController::Space.make(organization: org) }
      let!(:spaceBEnv) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'env', value: 'prod', space: spaceB) }
      let!(:spaceBAnimal) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'dog', space: spaceB) }

      let!(:spaceC) { VCAP::CloudController::Space.make(organization: org) }
      let!(:spaceCEnv) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'env', value: 'prod', space: spaceC) }
      let!(:spaceCAnimal) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'horse', space: spaceC) }

      let!(:spaceD) { VCAP::CloudController::Space.make(organization: org) }
      let!(:spaceDEnv) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'env', value: 'prod', space: spaceD) }

      let!(:spaceE) { VCAP::CloudController::Space.make(organization: org) }
      let!(:spaceEEnv) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'env', value: 'staging', space: spaceE) }
      let!(:spaceEAnimal) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'dog', space: spaceE) }

      let!(:orgF) { VCAP::CloudController::Organization.make(name: 'orgF', guid: 'orgF') }
      let!(:spaceF) { VCAP::CloudController::Space.make(organization: orgF, guid: 'spaceF') }
      let!(:spaceFEnv) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'env', value: 'prod', space: spaceF) }
      let!(:spaceFAnimal) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'cat', space: spaceF) }

      it 'returns the correct spaces' do
        get '/v3/spaces?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |space| space['guid'] }).to contain_exactly(spaceB.guid, spaceC.guid)
      end

      it 'returns the correct spaces when scoped to an org' do
        get "/v3/spaces?label_selector=!fruit,env=prod,animal in (cat,horse)&organization_guids=#{orgF.guid}", nil, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |space| space['guid'] }).to contain_exactly(spaceF.guid)
      end
    end

    context('including org') do
      # space with org1
      let!(:other_org_space) { VCAP::CloudController::Space.make name: 'Agricola', organization: org2 }
      let!(:org2) { VCAP::CloudController::Organization.make name: 'Videogames', created_at: 1.days.ago }

      it 'can includes all orgs for spaces' do
        get '/v3/spaces?include=organization', nil, admin_header
        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)

        orgs = parsed_response['included']['organizations']
        expect(orgs).to be_present
        expect(orgs.length).to eq 2
        org1 = space1.organization

        expect(orgs.map { |org| org['guid'] }).to eq [org1.guid, org2.guid]
        expect(orgs[0]).to be_a_response_like({
          'guid' => org1.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org1.name,
          'suspended' => false,
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}",
            },
            'default_domain' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains/default",
            },
            'domains' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains",
            },
            'quota' => {
              'href' => "#{link_prefix}/v3/organization_quotas/#{org1.quota_definition.guid}"
            }
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org1.quota_definition.guid } } },
        })
        expect(orgs[1]).to be_a_response_like({
          'guid' => org2.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org2.name,
          'suspended' => false,
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/organizations/#{org2.guid}",
            },
            'default_domain' => {
              'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains/default",
            },
            'domains' => {
              'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains",
            },
            'quota' => {
              'href' => "#{link_prefix}/v3/organization_quotas/#{org2.quota_definition.guid}"
            }
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org2.quota_definition.guid } } },
        })
      end

      it 'flags unsupported includes that contain supported ones' do
        get '/v3/spaces?include=organization,not_supported', nil, admin_header
        expect(last_response.status).to eq(400)
      end

      it 'does not include spaces if no one asks for them' do
        get '/v3/spaces', nil, admin_header
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to_not have_key('included')
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Space }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/spaces?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'GET /v3/spaces/:space_guid/staging_security_groups' do
    let!(:space) { VCAP::CloudController::Space.make }
    let!(:org) { space.organization }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make name: 'my_super_sec_group' }

    before do
      security_group.add_staging_space(space)
    end

    context 'with filters' do
      before do
        other_sec_group.add_staging_space(space)
      end

      let(:expected_response_objects) {
        [{
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'my_super_sec_group',
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: [
            {
              protocol: 'udp',
              ports: '8080',
              destination: '198.41.191.47/1'
            }
          ],
          relationships: {
            staging_spaces: {
              data: [
                { guid: space.guid }
              ]
            },
            running_spaces: {
              data: []
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }]
      }
      let(:other_sec_group) { VCAP::CloudController::SecurityGroup.make }

      it 'returns the filtered list' do
        get "/v3/spaces/#{space.guid}/staging_security_groups?names=my_super_sec_group", nil, admin_header
        expect(last_response).to have_status_code(200)
        expect({ resources: parsed_response['resources'] }).to match_json_response({ resources: expected_response_objects })

        expect(parsed_response['pagination']).to match_json_response({
          total_results: an_instance_of(Integer),
          total_pages: an_instance_of(Integer),
          first: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
          last: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
          next: anything,
          previous: anything
        })
      end
    end

    context 'with unaffiliated and globally affiliated security groups' do
      before do
        security_group.staging_default = true
      end

      let(:api_call) { lambda { |user_headers| get "/v3/spaces/#{space.guid}/staging_security_groups", nil, user_headers } }
      let(:response_object) {
        [
          {
            guid: security_group.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'my_super_sec_group',
            globally_enabled: {
              running: false,
              staging: false
            },
            rules: [
              {
                protocol: 'udp',
                ports: '8080',
                destination: '198.41.191.47/1'
              }
            ],
            relationships: {
              staging_spaces: {
                data: [
                  { guid: space.guid }
                ]
              },
              running_spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
          },
          {
            guid: global_sec_group.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'global',
            globally_enabled: {
              running: false,
              staging: true
            },
            rules: [
              {
                protocol: 'udp',
                ports: '8080',
                destination: '198.41.191.47/1'
              }
            ],
            relationships: {
              staging_spaces: {
                data: []
              },
              running_spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
          },

        ]
      }
      let(:unaffiliated_sec_group) { VCAP::CloudController::SecurityGroup.make }
      let(:global_sec_group) { VCAP::CloudController::SecurityGroup.make staging_default: true, name: 'global' }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(response_object)
        h = Hash.new(code: 404)
        h['admin'] = { code: 200, response_objects: response_object }
        h['admin_read_only'] = { code: 200, response_objects: response_object }
        h['global_auditor'] = { code: 200, response_objects: response_object }
        h['org_manager'] = { code: 200, response_objects: response_object }
        h['space_manager'] = { code: 200, response_objects: response_object }
        h['space_auditor'] = { code: 200, response_objects: response_object }
        h['space_developer'] = { code: 200, response_objects: response_object }
        h.freeze
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/spaces/:space_guid/running_security_groups' do
    let!(:space) { VCAP::CloudController::Space.make }
    let!(:org) { space.organization }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make name: 'my_super_sec_group' }

    before do
      security_group.add_space(space)
    end

    context 'with filters' do
      before do
        other_sec_group.add_space(space)
      end

      let(:expected_response_objects) {
        [{
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'my_super_sec_group',
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: [
            {
              protocol: 'udp',
              ports: '8080',
              destination: '198.41.191.47/1'
            }
          ],
          relationships: {
            staging_spaces: {
              data: []
            },
            running_spaces: {
              data: [
                { guid: space.guid }
              ]
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }]
      }
      let(:other_sec_group) { VCAP::CloudController::SecurityGroup.make }

      it 'returns the filtered list' do
        get "/v3/spaces/#{space.guid}/running_security_groups?names=my_super_sec_group", nil, admin_header
        expect(last_response).to have_status_code(200)
        expect({ resources: parsed_response['resources'] }).to match_json_response({ resources: expected_response_objects })

        expect(parsed_response['pagination']).to match_json_response({
          total_results: an_instance_of(Integer),
          total_pages: an_instance_of(Integer),
          first: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
          last: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
          next: anything,
          previous: anything
        })
      end
    end

    context 'with unaffiliated and globally affilated security groups' do
      before do
        security_group.running_default = true
      end

      let(:api_call) { lambda { |user_headers| get "/v3/spaces/#{space.guid}/running_security_groups", nil, user_headers } }
      let(:response_object) {
        [
          {
            guid: security_group.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'my_super_sec_group',
            globally_enabled: {
              running: false,
              staging: false
            },
            rules: [
              {
                protocol: 'udp',
                ports: '8080',
                destination: '198.41.191.47/1'
              }
            ],
            relationships: {
              staging_spaces: {
                data: []
              },
              running_spaces: {
                data: [
                  { guid: space.guid }
                ]
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
          },
          {
            guid: global_sec_group.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'global',
            globally_enabled: {
              running: true,
              staging: false
            },
            rules: [
              {
                protocol: 'udp',
                ports: '8080',
                destination: '198.41.191.47/1'
              }
            ],
            relationships: {
              staging_spaces: {
                data: []
              },
              running_spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
          },

        ]
      }
      let(:unaffiliated_sec_group) { VCAP::CloudController::SecurityGroup.make }
      let(:global_sec_group) { VCAP::CloudController::SecurityGroup.make running_default: true, name: 'global' }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = { code: 200, response_objects: response_object }
        h['admin_read_only'] = { code: 200, response_objects: response_object }
        h['global_auditor'] = { code: 200, response_objects: response_object }
        h['org_manager'] = { code: 200, response_objects: response_object }
        h['space_manager'] = { code: 200, response_objects: response_object }
        h['space_auditor'] = { code: 200, response_objects: response_object }
        h['space_developer'] = { code: 200, response_objects: response_object }
        h.freeze
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end

  describe 'PATCH /v3/spaces/:guid' do
    context 'updating the space to a duplicate name' do
      let(:space1) { VCAP::CloudController::Space.make(name: 'space1', organization: org) }
      let!(:space2) { VCAP::CloudController::Space.make(name: 'space2', organization: org) }

      it 'returns a 422 with a helpful error message' do
        patch "/v3/spaces/#{space1.guid}", { name: 'space2' }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq("Organization 'Boardgames' already contains a space with name 'space2'.")
      end
    end

    context 'updates the requested space' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }

      request_body = {
        name: 'codenames',
        metadata: {
          labels: {
            label: 'value'
          },
          annotations: {
            potato: 'yellow'
          }
        }
      }.to_json

      let(:space_json) do
        {
          guid: space.guid,
          name: 'codenames',
          created_at: iso8601,
          updated_at: iso8601,
          relationships: {
            organization: {
              data: { guid: space.organization_guid }
            },
            quota: {
              data: nil
            }
          },
          metadata: {
            labels: {
              label: 'value'
            },
            annotations: {
              potato: 'yellow'
            }
          },
          links: build_space_links(space)
        }
      end

      let(:api_call) { lambda { |user_headers| patch "/v3/spaces/#{space.guid}", request_body, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['org_billing_manager'] = { code: 404 }
        h['org_auditor'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = {
          code: 200,
          response_object: space_json
        }
        h['org_manager'] = {
          code: 200,
          response_object: space_json
        }
        h['space_manager'] = {
          code: 200,
          response_object: space_json
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          {
            type: 'audit.space.update',
            actee: space.guid,
            actee_type: 'space',
            actee_name: 'codenames',
            metadata: {
              request: {
                name: 'codenames',
                metadata: {
                  labels: {
                    label: 'value'
                  },
                  annotations: {
                    potato: 'yellow'
                  }
                }
              }
            }.to_json,
            space_guid: space.guid,
            organization_guid: space.organization_guid,
          }
        end
      end
    end

    context 'removing labels' do
      let!(:space1Label) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'fruit', value: 'mango', space: space1) }
      let!(:space1Label) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'animal', value: 'monkey', space: space1) }

      it 'removes a label from a space when the value is set to null' do
        patch "/v3/spaces/#{space1.guid}", { metadata: { labels: { fruit: nil } } }.to_json, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'guid' => space1.guid,
            'name' => space1.name,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => {
              'organization' => {
                'data' => { 'guid' => space1.organization_guid }
              },
              'quota' => {
                'data' => nil
              }
            },
            'metadata' => {
              'labels' => {
                'animal' => 'monkey'
              },
              'annotations' => {},
            },
            'links' => build_space_links(space1)
          }
        )
      end
    end

    context 'updating labels' do
      let!(:space1_label) { VCAP::CloudController::SpaceLabelModel.make(key_name: 'fruit', value: 'mango', space: space1) }

      it 'Updates the spaces label' do
        patch "/v3/spaces/#{space1.guid}", { metadata: { labels: { fruit: 'strawberry' } } }.to_json, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'guid' => space1.guid,
            'name' => space1.name,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => {
              'organization' => {
                'data' => { 'guid' => space1.organization_guid }
              },
              'quota' => {
                'data' => nil
              }
            },
            'metadata' => {
              'labels' => {
                'fruit' => 'strawberry'
              },
              'annotations' => {},
            },
            'links' => build_space_links(space1)
          }
        )
      end
    end
  end

  describe 'DELETE /v3/spaces/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:associated_user) { VCAP::CloudController::User.make(default_space: space) }
    let(:shared_service_instance) do
      s = VCAP::CloudController::ServiceInstance.make
      s.add_shared_space(space)
      s
    end
    let(:k8s_api_client) { instance_double(Kubernetes::ApiClient, delete_image: nil, delete_builder: nil) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:k8s_api_client).and_return(k8s_api_client)

      VCAP::CloudController::AppModel.make(space: space)
      VCAP::CloudController::Route.make(space: space)
      org.add_user(associated_user)
      space.add_developer(associated_user)
      VCAP::CloudController::ServiceInstance.make(space: space)
      VCAP::CloudController::ServiceBroker.make(space: space)
    end

    it 'destroys the requested space and sub resources' do
      expect {
        delete "/v3/spaces/#{space.guid}", nil, admin_header
        expect(last_response.status).to eq(202)
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        execute_all_jobs(expected_successes: 2, expected_failures: 0)
        get "/v3/spaces/#{space.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)
      }.to  change { VCAP::CloudController::Space.count }.by(-1).
        and change { VCAP::CloudController::AppModel.count }.by(-1).
        and change { VCAP::CloudController::Route.count }.by(-1).
        and change { associated_user.reload.default_space }.to(be_nil).
        and change { associated_user.reload.spaces }.to(be_empty).
        and change { VCAP::CloudController::ServiceInstance.count }.by(-1).
        and change { VCAP::CloudController::ServiceBroker.count }.by(-1).
        and change { shared_service_instance.reload.shared_spaces }.to(be_empty)
    end

    let(:api_call) { lambda { |user_headers| delete "/v3/spaces/#{space.guid}", nil, user_headers } }
    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        execute_all_jobs(expected_successes: 2, expected_failures: 0)
        get "/v3/spaces/#{space.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)
      end
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { space }
        let(:api_call) do
          -> { delete "/v3/spaces/#{space.guid}", nil, admin_header }
        end
      end
    end

    context 'when the user is a member in the spaces org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['org_billing_manager'] = { code: 404 }
        h['org_auditor'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 202 }
        h['org_manager'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          {
            type: 'audit.space.delete-request',
            actee: space.guid,
            actee_type: 'space',
            actee_name: space.name,
            metadata: { request: { recursive: true } }.to_json,
            space_guid: space.guid,
            organization_guid: org.guid,
          }
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/spaces/#{space.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'DELETE /v3/spaces/:guid/routes?unmapped=true' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let!(:unmapped_route) { VCAP::CloudController::Route.make(space: space, domain: domain) }
    let!(:mapped_route) { VCAP::CloudController::Route.make(space: space, domain: domain, host: 'mapped') }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let!(:destination) { VCAP::CloudController::RouteMappingModel.make(route: mapped_route, app: app_model) }

    let(:api_call) { lambda { |user_headers| delete "/v3/spaces/#{space.guid}/routes?unmapped=true", nil, user_headers } }

    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        get "/v3/routes/#{unmapped_route.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)

        get "/v3/routes/#{mapped_route.guid}", {}, admin_headers
        expect(last_response.status).to eq(200)
      end
    end

    context 'when the user is a member in the spaces org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)

        h['org_billing_manager'] = { code: 404 }
        h['org_auditor'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 202 }
        h['space_developer'] = { code: 202 }
        h['space_application_supporter'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS + ['space_application_supporter']
    end

    context 'when user does not specify unmapped query param' do
      it 'returns 422 with helpful error message' do
        delete "v3/spaces/#{space.guid}/routes", nil, admin_headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Mass delete not supported for routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
      end
    end
  end

  def build_space_links(space)
    {
      'self' => {
        'href' => "#{link_prefix}/v3/spaces/#{space.guid}"
      },
      'features' => {
        'href' => "#{link_prefix}/v3/spaces/#{space.guid}/features"
      },
      'organization' => {
        'href' => "#{link_prefix}/v3/organizations/#{space.organization_guid}"
      },
      'apply_manifest' => {
        'href' => "#{link_prefix}/v3/spaces/#{space.guid}/actions/apply_manifest",
        'method' => 'POST'
      }
    }
  end
end
