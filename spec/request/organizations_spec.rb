require 'spec_helper'

RSpec.describe 'Organizations' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let!(:organization1)            { VCAP::CloudController::Organization.make name: 'Apocalypse World' }
  let!(:organization2)            { VCAP::CloudController::Organization.make name: 'Dungeon World' }
  let!(:organization3)            { VCAP::CloudController::Organization.make name: 'The Sprawl' }
  let!(:unaccesable_organization) { VCAP::CloudController::Organization.make name: 'D&D' }

  let(:scheme) { TestConfig.config[:external_protocol] }
  let(:host) { TestConfig.config[:external_domain] }
  let(:link_prefix) { "#{scheme}://#{host}" }

  before do
    organization1.add_user(user)
    organization2.add_user(user)
    organization3.add_user(user)
  end

  describe 'GET /v3/organization' do
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
              'links' => {}
            },
            {
              'guid' => organization2.guid,
              'name' => 'Dungeon World',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {}
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
              'links' => {}
            },
            {
              'guid' => organization3.guid,
              'name' => 'The Sprawl',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {}
            }
          ]
        }
      )
    end
  end
end
