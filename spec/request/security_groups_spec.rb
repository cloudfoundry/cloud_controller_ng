require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Security_Groups Request' do
  let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid') }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
  let(:admin_header) { admin_headers_for(user) }
  let(:default_rules) do
    [
      {
        protocol: 'udp',
        ports: '8080',
        destination: '198.41.191.47/1',
      }
    ]
  end

  describe 'POST /v3/security_groups' do
    let(:api_call) { lambda { |user_headers| post '/v3/security_groups', params.to_json, user_headers } }

    context 'creating a security group' do
      let(:security_group_name) { 'security_group_name' }
      let(:rules) { [] }

      let(:params) do
        {
          name: security_group_name,
          globally_enabled: {
            running: true,
            staging: false
          },
          rules: rules,
          relationships: {
            staging_spaces: {
              data: [
                { guid: space.guid },
              ]
            },
            running_spaces: {
              data: []
            }
          },
        }
      end

      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group_name,
          globally_enabled: {
            running: true,
            staging: false
          },
          rules: [],
          relationships: {
            staging_spaces: {
              data: [
                { guid: 'space-guid' },
              ]
            },
            running_spaces: {
              data: []
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when creating a security group with rules' do
        let(:rules) do
          [
            {
              protocol: 'tcp',
              destination: '10.10.10.0/24',
              ports: '443,80,8080'
            },
            {
              protocol: 'icmp',
              destination: '10.10.10.0/24',
              type: 8,
              code: 0,
              description: 'Allow ping requests to private services'
            },
          ]
        end

        let(:expected_response) do
          {
            guid: UUID_REGEX,
            created_at: iso8601,
            updated_at: iso8601,
            name: security_group_name,
            globally_enabled: {
              running: true,
              staging: false
            },
            rules: [
              {
                protocol: 'tcp',
                destination: '10.10.10.0/24',
                ports: '443,80,8080'
              },
              {
                protocol: 'icmp',
                destination: '10.10.10.0/24',
                type: 8,
                code: 0,
                description: 'Allow ping requests to private services'
              },
            ],
            relationships: {
              staging_spaces: {
                data: [
                  { guid: 'space-guid' },
                ]
              },
              running_spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
          }
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      if ENV['DB'] == 'mysql'
        context 'when the security group name is invalid' do
          let(:params) do
            {
              name: '🐸🐞'
            }
          end

          it 'returns a 422 with a helpful message' do
            post '/v3/security_groups', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              'Security group name contains invalid characters.'
            )
          end
        end

        context 'when the security group rules are invalid' do
          let(:params) do
            {
              name: 'bad-rules',
              rules: [
                { protocol: 'all', destination: '0.0.0.0', description: 'asd🐞f' }
              ]
            }
          end

          it 'returns a 422 with a helpful message' do
            post '/v3/security_groups', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              'Security group rules contain invalid characters.'
            )
          end
        end
      end

      context 'when a security group with name that already exists' do
        before do
          post '/v3/security_groups', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/security_groups', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message(
            "Security group with name '#{security_group_name}' already exists."
                                   )
        end
      end
    end
  end

  describe 'POST /v3/security_groups/:security_group_guid/relationships/running_spaces' do
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:api_call) { lambda { |user_headers| post "/v3/security_groups/#{security_group.guid}/relationships/running_spaces", params.to_json, user_headers } }

    context 'bind running security group to a space' do
      context 'when the security group is NOT globally enabled NOR associated with any spaces' do
        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: [
              { guid: 'space-guid' },
            ],
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/running_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = {
            code: 200,
            response_object: expected_response
          }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is NOT globally enabled, associated with spaces' do
        before do
          security_group.add_space(another_space)
          security_group.add_staging_space(space)
        end

        let(:another_space) { VCAP::CloudController::Space.make(guid: 'another-space-guid') }
        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: contain_exactly(
              { guid: 'space-guid' },
              { guid: 'another-space-guid' },
            ),
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/running_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = h['space_manager'] = h['org_manager'] = {
            code: 200,
            response_object: expected_response
          }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is globally enabled' do
        before do
          security_group.update(running_default: true)
        end

        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: [
              { guid: 'space-guid' },
            ],
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/running_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = h['space_manager'] = h['org_manager'] = {
            code: 200,
            response_object: expected_response
          }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group does not exist' do
        it 'returns a 404' do
          post '/v3/security_groups/non-existent-group/relationships/running_spaces', {}.to_json, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Security group not found')
        end
      end

      context 'when the space is invalid' do
        let(:params) do
          {
            data: [
              { guid: 'non-existent-space' },
            ]
          }
        end

        it 'returns an error' do
          post "/v3/security_groups/#{security_group.guid}/relationships/running_spaces", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Spaces with guids ["non-existent-space"] do not exist, or you do not have access to them.')
        end
      end
    end
  end

  describe 'POST /v3/security_groups/:security_group_guid/relationships/staging_spaces' do
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:api_call) { lambda { |user_headers| post "/v3/security_groups/#{security_group.guid}/relationships/staging_spaces", params.to_json, user_headers } }

    context 'bind staging security group to a space' do
      context 'when the security group is NOT globally enabled NOR associated with any spaces' do
        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: [
              { guid: 'space-guid' },
            ],
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/staging_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = {
            code: 200,
            response_object: expected_response
          }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is NOT globally enabled, associated with spaces' do
        before do
          security_group.add_space(space)
          security_group.add_staging_space(another_space)
        end

        let(:another_space) { VCAP::CloudController::Space.make(guid: 'another-space-guid') }
        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: contain_exactly(
              { guid: 'space-guid' },
              { guid: 'another-space-guid' },
            ),
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/staging_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = h['space_manager'] = h['org_manager'] = {
            code: 200,
            response_object: expected_response
          }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is globally enabled' do
        before do
          security_group.update(staging_default: true)
        end

        let(:params) do
          {
            data: [
              { guid: space.guid },
            ]
          }
        end

        let(:expected_response) do
          {
            data: [
              { guid: 'space-guid' },
            ],
            links: {
              self: {
                href: "#{link_prefix}/v3/security_groups/#{security_group.guid}/relationships/staging_spaces"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = h['space_manager'] = h['org_manager'] = {
            code: 200,
            response_object: expected_response
          }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the security group does not exist' do
        it 'returns a 404' do
          post '/v3/security_groups/non-existent-group/relationships/staging_spaces', {}.to_json, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Security group not found')
        end
      end

      context 'when the space is invalid' do
        let(:params) do
          {
            data: [
              { guid: 'non-existent-space' },
            ]
          }
        end

        it 'returns an error' do
          post "/v3/security_groups/#{security_group.guid}/relationships/staging_spaces", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Spaces with guids ["non-existent-space"] do not exist, or you do not have access to them.')
        end
      end
    end
  end

  describe 'GET /v3/security_groups' do
    let(:api_call) { lambda { |user_headers| get '/v3/security_groups', nil, user_headers } }
    let(:security_group_1) { VCAP::CloudController::SecurityGroup.make(guid: 'security_group_1_guid') }
    let(:security_group_2) { VCAP::CloudController::SecurityGroup.make(guid: 'security_group_2_guid') }
    let(:security_group_3) { VCAP::CloudController::SecurityGroup.make(running_default: true, guid: 'security_group_3_guid') }

    before do
      security_group_2.add_staging_space(space)
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::SecurityGroup }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/security_groups?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    context 'getting security groups' do
      let(:expected_response_1) do
        {
          guid: security_group_1.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group_1.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/security_group_1_guid) },
          }
        }
      end

      let(:expected_response_2) do
        {
          guid: security_group_2.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group_2.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [{ guid: 'space-guid' }],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/security_group_2_guid) },
          }
        }
      end

      let(:expected_response_3) do
        {
          guid: security_group_3.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group_3.name,
          globally_enabled: {
            running: true,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/security_group_3_guid) },
          }
        }
      end

      let(:expected_response_dummy_1) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'dummy1',
          globally_enabled: {
            running: false,
            staging: false,
          },
          rules: [],
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links:
            {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
        }
      end

      let(:expected_response_dummy_2) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'dummy2',
          globally_enabled: {
            running: false,
            staging: false,
          },
          rules: [],
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links:
            {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
            }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [])
        h['admin'] = {
          code: 200,
          response_objects: contain_exactly(expected_response_1, expected_response_2, expected_response_3, expected_response_dummy_1, expected_response_dummy_2)
        }
        h['admin_read_only'] = {
          code: 200,
          response_objects: contain_exactly(expected_response_1, expected_response_2, expected_response_3, expected_response_dummy_1, expected_response_dummy_2)
        }
        h['global_auditor'] = {
          code: 200,
          response_objects: contain_exactly(expected_response_1, expected_response_2, expected_response_3, expected_response_dummy_1, expected_response_dummy_2)
        }
        h['space_developer'] = {
          code: 200,
          response_objects: [expected_response_2, expected_response_3]
        }
        h['space_manager'] = {
          code: 200,
          response_objects: [expected_response_2, expected_response_3]
        }
        h['space_auditor'] = {
          code: 200,
          response_objects: [expected_response_2, expected_response_3]
        }
        h['org_manager'] = {
          code: 200,
          response_objects: [expected_response_2, expected_response_3]
        }
        h['org_auditor'] = {
          code: 200,
          response_objects: [expected_response_3]
        }
        h['org_billing_manager'] = {
          code: 200,
          response_objects: [expected_response_3]
        }
        h['no_role'] = {
          code: 200,
          response_objects: [expected_response_3]
        }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'filtering security groups' do
      before do
        security_group_2.add_space(space)
        security_group_3.update(staging_default: true)
      end

      it 'filters on guids' do
        get "/v3/security_groups?guids=#{security_group_2.guid}", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_2.guid)
      end

      it 'filters on names' do
        get "/v3/security_groups?names=#{security_group_2.name}", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_2.guid)
      end

      it 'filters on running_space_guids' do
        get "/v3/security_groups?running_space_guids=#{space.guid}", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_2.guid)
      end

      it 'filters on staging_space_guids' do
        get "/v3/security_groups?staging_space_guids=#{space.guid}", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_2.guid)
      end

      it 'filters on globally_enabled_staging' do
        get '/v3/security_groups?globally_enabled_staging=true', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_3.guid)
      end

      it 'filters on globally_enabled_running' do
        get '/v3/security_groups?globally_enabled_running=true', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(security_group_3.guid)
      end
    end

    context 'when given an invalid query parameter' do
      it 'returns a 422 with a helpful error message' do
        get '/v3/security_groups?blork=busted', nil, admin_header

        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Unknown query parameter(s): 'blork'. Valid parameters are: " \
            "'page', 'per_page', 'order_by', 'created_ats', 'updated_ats', 'guids', 'names', 'running_space_guids', " \
            "'staging_space_guids', 'globally_enabled_running', 'globally_enabled_staging'")
      end
    end
  end

  describe 'GET /v3/security_groups/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/security_groups/#{security_group.guid}", nil, user_headers } }

    context 'getting a security group NOT globally enabled NOR associated with any spaces' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['admin_read_only'] = {
          code: 200,
          response_object: expected_response
        }
        h['global_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'getting a security group NOT globally enabled, associated with spaces' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      before do
        security_group.add_staging_space(space)
      end

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [{ guid: space.guid }],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['admin_read_only'] = {
          code: 200,
          response_object: expected_response
        }
        h['global_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_developer'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_manager'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h['org_manager'] = {
          code: 200,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'getting a security group globally enabled' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make(running_default: true) }

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: true,
            staging: false
          },
          rules: default_rules,
          relationships: {
            staging_spaces: {
              data: [],
            },
            running_spaces: {
              data: [],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        Hash.new(code: 200, response_object: expected_response)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'security group does not exist' do
      it 'returns a 404 with a helpful message' do
        get '/v3/security_groups/fake-security-group', nil, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message(
          'Security group not found'
                                 )
      end
    end
  end

  describe 'PATCH /v3/security_groups/:guid' do
    let(:api_call) { lambda { |user_headers| patch "/v3/security_groups/#{security_group.guid}", params.to_json, user_headers } }
    let!(:security_group) do
      VCAP::CloudController::SecurityGroup.make({
        name: 'original-name',
        rules: [],
      })
    end

    let(:params) do
      {
        name: 'updated-name',
        globally_enabled: {
          running: false,
          staging: true,
        },
        rules: [
          {
            'protocol' => 'udp',
            'ports' => '8080',
            'destination' => '198.41.191.47/1'
          }
        ],
      }
    end

    context 'when the security group only globally enabled' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make(running_default: true) }

      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'updated-name',
          globally_enabled: {
            running: false,
            staging: true
          },
          rules: [
            {
              'protocol' => 'udp',
              'ports' => '8080',
              'destination' => '198.41.191.47/1'
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
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the security group is applied to a space' do
      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'updated-name',
          globally_enabled: {
            running: false,
            staging: true
          },
          rules: [
            {
              'protocol' => 'udp',
              'ports' => '8080',
              'destination' => '198.41.191.47/1'
            }
          ],
          relationships: {
            staging_spaces: {
              data: [{ guid: space.guid }],
            },
            running_spaces: {
              data: []
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      before do
        security_group.add_staging_space(space)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the security group is neither globally enabled nor associated with any spaces' do
      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'updated-name',
          globally_enabled: {
            running: false,
            staging: true
          },
          rules: [
            {
              'protocol' => 'udp',
              'ports' => '8080',
              'destination' => '198.41.191.47/1'
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
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['global_auditor'] = { code: 403 }
        h['admin_read_only'] = { code: 403 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'performing a partial update' do
      let(:params) do
        {
          globally_enabled: {
            staging: true,
          },
        }
      end

      it 'only updates the requested fields' do
        patch "/v3/security_groups/#{security_group.guid}", params.to_json, admin_header

        expect(last_response).to have_status_code(200)
        expect(security_group.reload.name).to eq('original-name')
        expect(security_group.reload.running_default).to eq(false)
        expect(security_group.reload.staging_default).to eq(true)
        expect(security_group.reload.rules).to eq([])
      end
    end

    context 'when the params are empty' do
      it 'does not update the security group' do
        patch "/v3/security_groups/#{security_group.guid}", {}.to_json, admin_header

        expect(last_response).to have_status_code(200)
        expect(security_group.reload.name).to eq('original-name')
        expect(security_group.reload.running_default).to eq(false)
        expect(security_group.reload.staging_default).to eq(false)
        expect(security_group.reload.rules).to eq([])
      end
    end

    context 'when the security group does not exist' do
      it 'returns a 404 with a helpful message' do
        patch '/v3/security_groups/not-exist', params.to_json, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Security group not found')
      end
    end

    context 'when updating to a name that is already taken' do
      let!(:another_security_group) { VCAP::CloudController::SecurityGroup.make(name: 'already-taken') }
      let(:params) { { name: 'already-taken' } }

      it 'returns a 422 with a helpful message' do
        patch "/v3/security_groups/#{security_group.guid}", params.to_json, admin_header

        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Security group with name 'already-taken' already exists")
      end
    end

    if ENV['DB'] == 'mysql'
      context 'when the security group name is invalid' do
        let(:params) do
          {
            name: '🐸🐞'
          }
        end

        it 'returns a 422 with a helpful message' do
          patch "/v3/security_groups/#{security_group.guid}", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message(
            'Security group name contains invalid characters.'
          )
        end
      end

      context 'when the security group rules are invalid' do
        let(:params) do
          {
            rules: [
              { protocol: 'all', destination: '0.0.0.0', description: 'asd🐞f' }
            ]
          }
        end

        it 'returns a 422 with a helpful message' do
          patch "/v3/security_groups/#{security_group.guid}", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message(
            'Security group rules contain invalid characters.'
          )
        end
      end
    end
  end

  describe 'DELETE /v3/security_groups/:security_group_guid/relationships/running_spaces/:space_guid' do
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:api_call) { lambda { |user_headers| delete "/v3/security_groups/#{security_group.guid}/relationships/running_spaces/#{space.guid}", nil, user_headers } }

    context 'unbinding a running security group from a space' do
      context 'when the security group is NOT globally enabled NOR associated with any spaces' do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = { code: 422 }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is NOT globally enabled, associated with spaces' do
        before do
          security_group.add_space(space)
        end

        let(:db_check) do
          lambda do
            expect(security_group.reload.spaces.count).to eq(0)
          end
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 204 }
          h['space_manager'] = { code: 204 }
          h['org_manager'] = { code: 204 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is globally enabled and associated with spaces' do
        before do
          security_group.update(running_default: true)
          security_group.add_space(space)
        end

        let(:db_check) do
          lambda do
            expect(security_group.reload.spaces.count).to eq(0)
          end
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 204 }
          h['space_manager'] = { code: 204 }
          h['org_manager'] = { code: 204 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group does not exist' do
        it 'returns a 404' do
          delete "/v3/security_groups/non-existent-group/relationships/running_spaces/#{space.guid}", nil, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Security group not found')
        end
      end

      context 'when the space is invalid' do
        it 'returns an error' do
          delete "/v3/security_groups/#{security_group.guid}/relationships/running_spaces/fake-space", nil, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Unable to unbind security group from space with guid 'fake-space'. Ensure the space is bound to this security group.")
        end
      end
    end
  end

  describe 'DELETE /v3/security_groups/:security_group_guid/relationships/staging_spaces/:space_guid' do
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:api_call) { lambda { |user_headers| delete "/v3/security_groups/#{security_group.guid}/relationships/staging_spaces/#{space.guid}", nil, user_headers } }

    context 'unbinding a staging security group from a space' do
      context 'when the security group is NOT globally enabled NOR associated with any spaces' do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = { code: 422 }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is NOT globally enabled, associated with spaces' do
        before do
          security_group.add_staging_space(space)
        end

        let(:db_check) do
          lambda do
            expect(security_group.reload.staging_spaces.count).to eq(0)
          end
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 204 }
          h['space_manager'] = { code: 204 }
          h['org_manager'] = { code: 204 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group is globally enabled and associated with spaces' do
        before do
          security_group.update(staging_default: true)
          security_group.add_staging_space(space)
        end

        let(:db_check) do
          lambda do
            expect(security_group.reload.staging_spaces.count).to eq(0)
          end
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 204 }
          h['space_manager'] = { code: 204 }
          h['org_manager'] = { code: 204 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the security group does not exist' do
        it 'returns a 404' do
          delete "/v3/security_groups/non-existent-group/relationships/staging_spaces/#{space.guid}", nil, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Security group not found')
        end
      end

      context 'when the space is invalid' do
        it 'returns an error' do
          delete "/v3/security_groups/#{security_group.guid}/relationships/staging_spaces/fake-space", nil, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Unable to unbind security group from space with guid 'fake-space'. Ensure the space is bound to this security group.")
        end
      end
    end
  end

  describe 'DELETE /v3/security_groups/:guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/security_groups/#{security_group.guid}", nil, user_headers } }
    let(:db_check) do
      lambda do
        last_job = VCAP::CloudController::PollableJobModel.last
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{last_job.guid}))
        expect(last_job.resource_type).to eq('security_group')

        get "/v3/jobs/#{last_job.guid}", nil, admin_header
        expect(last_response).to have_status_code(200)
        expect(parsed_response['operation']).to eq('security_group.delete')
        expect(parsed_response['links']['security_group']['href']).to match(%r(/v3/security_groups/#{security_group.guid}))

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        get "/v3/security_groups/#{security_group.guid}", nil, admin_header
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the security group is only globally enabled' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make(running_default: true) }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    context 'when the security group is applied to a space but not globally enabled' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 202 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      before do
        security_group.add_staging_space(space)
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    context 'when the security group is neither globally enabled nor associated with any spaces' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = { code: 202 }
        h['global_auditor'] = { code: 403 }
        h['admin_read_only'] = { code: 403 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end
  end
end
