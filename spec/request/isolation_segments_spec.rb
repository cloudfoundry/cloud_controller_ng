require 'spec_helper'
require 'isolation_segment_assign'

RSpec.describe 'IsolationSegmentModels' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

  describe 'POST /v3/isolation_segments' do
    it 'creates an isolation segment' do
      create_request = {
        name: 'my_segment',
        metadata: {
          labels: { release: 'stable' },
          annotations: { note: 'this info' }
        }
      }

      post '/v3/isolation_segments', create_request.to_json, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(201)

      created_isolation_segment = VCAP::CloudController::IsolationSegmentModel.last
      expected_response = {
        'name'       => 'my_segment',
        'guid'       => created_isolation_segment.guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links'      => {
          'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{created_isolation_segment.guid}" },
          'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{created_isolation_segment.guid}/organizations" },
        },
        'metadata' => {
          'annotations' => { 'note' => 'this info' },
          'labels' => { 'release' => 'stable' }
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/isolation_segments/:guid/relationships/organizations' do
    let(:org1) { FactoryBot.create(:organization) }
    let(:org2) { FactoryBot.create(:organization) }
    let(:isolation_segment_model) { FactoryBot.create(:isolation_segment) }

    before do
      assigner.assign(isolation_segment_model, [org1, org2])
    end

    it 'returns the organization guids assigned' do
      get "/v3/isolation_segments/#{isolation_segment_model.guid}/relationships/organizations", nil, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => org1.guid },
          { 'guid' => org2.guid },
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/relationships/organizations" },
          'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/organizations" }
        }
      }

      expect(parsed_response['data'].length).to eq 2
      expect(parsed_response['data']).to include(expected_response['data'][0])
      expect(parsed_response['data']).to include(expected_response['data'][1])
      expect(parsed_response.except('data')).to be_a_response_like(expected_response.except('data'))
    end
  end

  describe 'GET /v3/isolation_segments/:guid/relationships/spaces' do
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }
    let(:isolation_segment_model) { FactoryBot.create(:isolation_segment) }

    before do
      assigner.assign(isolation_segment_model, [space1.organization, space2.organization])
      isolation_segment_model.add_space(space1)
      isolation_segment_model.add_space(space2)
    end

    it 'returns the guids of the associated spaces' do
      get "/v3/isolation_segments/#{isolation_segment_model.guid}/relationships/spaces", nil, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expect(parsed_response['data'].length).to eq 2
      expect(parsed_response['data']).to include({ 'guid' => space1.guid })
      expect(parsed_response['data']).to include({ 'guid' => space2.guid })
      expect(parsed_response['links']).to eq({
        'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/relationships/spaces" },
      })
    end
  end

  describe 'POST /v3/isolation_segments/:guid/relationships/organizations' do
    let(:org1) { FactoryBot.create(:organization) }
    let(:org2) { FactoryBot.create(:organization) }
    let(:isolation_segment) { FactoryBot.create(:isolation_segment) }

    it 'assigns the isolation segment to the organization' do
      assign_request = {
        data: [
          { guid: org1.guid }
        ]
      }

      post "/v3/isolation_segments/#{isolation_segment.guid}/relationships/organizations", assign_request.to_json, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => org1.guid }
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/relationships/organizations" },
          'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations" },
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'DELETE /v3/isolation_segments/:guid/relationships/organizations/:org_guid' do
    let(:org1) { FactoryBot.create(:organization) }
    let(:org2) { FactoryBot.create(:organization) }
    let(:isolation_segment) { FactoryBot.create(:isolation_segment) }

    before do
      assigner.assign(isolation_segment, [org1, org2])
    end

    it 'removes the organization from the isolation segment' do
      delete "/v3/isolation_segments/#{isolation_segment.guid}/relationships/organizations/#{org1.guid}", nil, user_header

      expect(last_response.status).to eq(204)
      isolation_segment.reload
      expect(isolation_segment.organizations).to include(org2)
      expect(isolation_segment.organizations).to_not include(org1)
    end
  end

  describe 'GET /v3/isolation_segments/:guid' do
    let(:isolation_segment_model) { FactoryBot.create(:isolation_segment) }

    context 'as an admin' do
      it 'returns the requested isolation segment' do
        get "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'name'       => isolation_segment_model.name,
          'guid'       => isolation_segment_model.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links'      => {
            'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}" },
            'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/organizations" },
          },
          'metadata' => {
            'annotations' => {},
            'labels' => {}
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    context 'when a user has read permissions for a space associated to an isolation_segment' do
      let(:user_header) { headers_for(user) }

      before do
        assigner.assign(isolation_segment_model, [space.organization])
        space.update(isolation_segment_guid: isolation_segment_model.guid)
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'returns the requested isolation segment' do
        get "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'name'       => isolation_segment_model.name,
          'guid'       => isolation_segment_model.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links'      => {
            'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}" },
            'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/organizations" },
          },
          'metadata' => {
            'annotations' => {},
            'labels' => {}
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end
  end

  describe 'GET /v3/isolation_segments' do
    let(:org1) { FactoryBot.create(:organization) }
    let(:org2) { FactoryBot.create(:organization) }

    it 'returns the seeded isolation segment' do
      get '/v3/isolation_segments', nil, user_header

      expect(last_response.status).to eq 200
      parsed_response = MultiJson.load(last_response.body)

      shared_guid = VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID

      expected_response = {
        'pagination' => {
          'total_results' =>  1,
          'total_pages'   =>  1,
          'first'         =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=1&per_page=50" },
          'last'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=1&per_page=50" },
          'next'          =>  nil,
          'previous'      =>  nil
        },
        'resources' => [
          {
            'name'       => 'shared',
            'guid'       => shared_guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links'      => {
              'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{shared_guid}" },
              'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{shared_guid}/organizations" },
            },
            'metadata' => {
              'annotations' => {},
              'labels' => {}
            }
          }
        ]
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'when there are multiple isolation segments' do
      let!(:models) {
        [
          FactoryBot.create(:isolation_segment, name: 'segment1'),
          FactoryBot.create(:isolation_segment, name: 'segment2'),
          FactoryBot.create(:isolation_segment, name: 'segment3'),
          FactoryBot.create(:isolation_segment, name: 'segment4'),
          FactoryBot.create(:isolation_segment, name: 'segment5'),
          FactoryBot.create(:isolation_segment, name: 'segment6')
        ]
      }

      # We do not account for the first isolation segment as it is a seed in the database.
      it 'returns a paginated list of the isolation segments' do
        get '/v3/isolation_segments?per_page=2&page=2', nil, user_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'pagination' => {
            'total_results' =>  7,
            'total_pages'   =>  4,
            'first'         =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=1&per_page=2" },
            'last'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=4&per_page=2" },
            'next'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=3&per_page=2" },
            'previous'      =>  { 'href' => "#{link_prefix}/v3/isolation_segments?page=1&per_page=2" }
          },
          'resources' => [
            {
              'guid'        =>  models[1].guid.to_s,
              'name'        =>  models[1].name.to_s,
              'created_at'  =>  iso8601,
              'updated_at'  =>  iso8601,
              'links'       =>  {
                'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{models[1].guid}" },
                'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{models[1].guid}/organizations" },
              },
              'metadata' => {
                'annotations' => {},
                'labels' => {}
            }
            },
            {
              'guid'        =>  models[2].guid.to_s,
              'name'        =>  models[2].name.to_s,
              'created_at'  =>  iso8601,
              'updated_at'  =>  iso8601,
              'links'       =>  {
                'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{models[2].guid}" },
                'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{models[2].guid}/organizations" },
              },
              'metadata' => {
                'annotations' => {},
                'labels' => {}
              }
            }
          ]
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end

      it 'filters by isolation segment names' do
        get "/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}", nil, user_header

        expected_pagination = {
          'total_results' =>  2,
          'total_pages'   =>  1,
          'first'         =>  { 'href' => "#{link_prefix}/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}&page=1&per_page=50" },
          'last'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}&page=1&per_page=50" },
          'next'          =>  nil,
          'previous'      =>  nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq([models[2].name, models[4].name])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by isolation segment guids' do
        get "/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}", nil, user_header

        expected_pagination = {
          'total_results' =>  2,
          'total_pages'   =>  1,
          'first'         =>  { 'href' => "#{link_prefix}/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}&page=1&per_page=50" },
          'last'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}&page=1&per_page=50" },
          'next'          =>  nil,
          'previous'      =>  nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq([models[3].name, models[5].name])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      context 'and isolation segments are assigned to orgs' do
        before do
          assigner.assign(models[1], [org1])
          assigner.assign(models[2], [org2])
        end

        it 'filters by organization guids' do
          get "/v3/isolation_segments?organization_guids=#{org1.guid}%2C#{org2.guid}", nil, user_header

          expected_pagination = {
            'total_results' =>  2,
            'total_pages'   =>  1,
            'first'         =>  { 'href' => "#{link_prefix}/v3/isolation_segments?organization_guids=#{org1.guid}%2C#{org2.guid}&page=1&per_page=50" },
            'last'          =>  { 'href' => "#{link_prefix}/v3/isolation_segments?organization_guids=#{org1.guid}%2C#{org2.guid}&page=1&per_page=50" },
            'next'          =>  nil,
            'previous'      =>  nil
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].map { |r| r['name'] }).to eq([models[1].name, models[2].name])
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end
    end

    context 'label_selector' do
      let!(:iso_segA) { FactoryBot.create(:isolation_segment, name: 'segmentA') }
      let!(:iso_segB) { FactoryBot.create(:isolation_segment, name: 'segmentB') }
      let!(:iso_segC) { FactoryBot.create(:isolation_segment, name: 'segmentC') }

      let!(:isoAFruit) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'fruit', value: 'strawberry', resource_guid: iso_segA.guid) }
      let!(:isoAAnimal) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'animal', value: 'horse', resource_guid: iso_segA.guid) }

      let!(:isoBEnv) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'env', value: 'prod', resource_guid: iso_segB.guid) }
      let!(:isoBAnimal) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'animal', value: 'dog', resource_guid: iso_segB.guid) }

      let!(:isoCEnv) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'env', value: 'prod', resource_guid: iso_segC.guid) }
      let!(:isoCAnimal) { VCAP::CloudController::IsolationSegmentLabelModel.make(key_name: 'animal', value: 'horse', resource_guid: iso_segC.guid) }

      it 'returns the matching iso segs' do
        get '/v3/isolation_segments?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_headers
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(iso_segB.guid, iso_segC.guid)
      end
    end
  end

  describe 'PATCH /v3/isolation_segments/:guid' do
    it 'updates the specified isolation segment' do
      isolation_segment_model = FactoryBot.create(:isolation_segment, name: 'my_segment')

      update_request = {
        name: 'your_segment',
        metadata: {
          labels: {
            one: 'two'
          },
          annotations: {
            three: 'four'
          }
        }
      }

      expected_response = {
        'name'       => 'your_segment',
        'guid'       => isolation_segment_model.guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links'      => {
          'self' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}" },
          'organizations' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}/organizations" },
        },
        'metadata' => {
          'labels' => { 'one' => 'two' },
          'annotations' => { 'three' => 'four' },
        }
      }

      patch "/v3/isolation_segments/#{isolation_segment_model.guid}", update_request.to_json, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'DELETE /v3/isolation_segments/:guid' do
    it 'deletes the specified isolation segment' do
      isolation_segment_model = FactoryBot.create(:isolation_segment, name: 'my_segment')

      delete "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header
      expect(last_response.status).to eq(204)
    end
  end
end
