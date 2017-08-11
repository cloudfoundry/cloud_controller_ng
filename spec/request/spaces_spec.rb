require 'spec_helper'

RSpec.describe 'Spaces' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:admin_header) { admin_headers_for(user) }
  let(:organization)       { VCAP::CloudController::Organization.make name: 'Boardgames' }
  let!(:space1)            { VCAP::CloudController::Space.make name: 'Catan', organization: organization }
  let!(:space2)            { VCAP::CloudController::Space.make name: 'Ticket to Ride', organization: organization }
  let!(:space3)            { VCAP::CloudController::Space.make name: 'Agricola', organization: organization }
  let!(:unaccesable_space) { VCAP::CloudController::Space.make name: 'Ghost Stories', organization: organization }

  before do
    organization.add_user(user)
    space1.add_developer(user)
    space2.add_developer(user)
    space3.add_developer(user)
  end

  describe 'POST /v3/spaces' do
    it 'creates a new space with the given name and org' do
      request_body = {
        name: 'space1',
        relationships: {
          organization: {
            data: { guid: organization.guid }
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
          'guid'       => created_space.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name'       => 'space1',
          'links'      => {
            'self' => { 'href' => "#{link_prefix}/v3/spaces/#{created_space.guid}" },
            'organization' => { 'href' => "#{link_prefix}/v3/organizations/#{created_space.organization_guid}" },
          }
        }
      )
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
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/spaces/#{space1.guid}"
              },
              'organization' => {
                'href' => "#{link_prefix}/v3/organizations/#{space1.organization_guid}"
              }
            }
        }
      )
    end
  end

  describe 'GET /v3/spaces' do
    it 'returns a paginated list of orgs the user has access to' do
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
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/spaces/#{space1.guid}"
                },
                'organization' => {
                  'href' => "#{link_prefix}/v3/organizations/#{space1.organization_guid}"
                }
              }
            },
            {
              'guid' => space2.guid,
              'name' => 'Ticket to Ride',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/spaces/#{space2.guid}"
                },
                'organization' => {
                  'href' => "#{link_prefix}/v3/organizations/#{space2.organization_guid}"
                }
              }
            }
          ]
        }
      )
    end
  end
end
