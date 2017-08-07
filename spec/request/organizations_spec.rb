require 'spec_helper'

RSpec.describe 'Organizations' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:admin_header) { admin_headers_for(user) }
  let!(:organization1) { VCAP::CloudController::Organization.make name: 'Apocalypse World' }
  let!(:organization2) { VCAP::CloudController::Organization.make name: 'Dungeon World' }
  let!(:organization3) { VCAP::CloudController::Organization.make name: 'The Sprawl' }
  let!(:unaccesable_organization) { VCAP::CloudController::Organization.make name: 'D&D' }

  before do
    organization1.add_user(user)
    organization2.add_user(user)
    organization3.add_user(user)
  end

  describe 'POST /v3/organizations' do
    it 'creates a new organization with the given name' do
      request_body = {
        name: 'org1'
      }.to_json

      expect {
        post '/v3/organizations', request_body, admin_header
      }.to change {
        VCAP::CloudController::Organization.count
      }.by 1

      created_org = VCAP::CloudController::Organization.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'guid'       => created_org.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name'       => 'org1',
          'links'      => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{created_org.guid}" }
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
            'total_pages'   => 2,
            'first'         => {
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
              'guid'       => organization1.guid,
              'name'       => 'Apocalypse World',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links'      => {
                'self' => {
                  'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}"
                }
              }
            },
            {
              'guid'       => organization2.guid,
              'name'       => 'Dungeon World',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links'      => {
                'self' => {
                  'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                }
              },
            }
          ]
        }
      )
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
            'total_pages'   => 1,
            'first'         => {
              'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
            },
            'next'          => nil,
            'previous'      => nil
          },
          'resources' => [
            {
              'guid'       => organization2.guid,
              'name'       => 'Dungeon World',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links'      => {
                'self' => {
                  'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                }
              },
            },
            {
              'guid'       => organization3.guid,
              'name'       => 'The Sprawl',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links'      => {
                'self' => {
                  'href' => "#{link_prefix}/v3/organizations/#{organization3.guid}"
                }
              },
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
          'self'    => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
          'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
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
          'self'    => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
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
end
