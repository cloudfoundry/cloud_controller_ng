require 'spec_helper'

RSpec.describe 'IsolationSegmentModels' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }

  describe 'GET /v3/isolation_segments' do
    let!(:models) {
      [
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment1'),
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment2'),
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment3'),
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment4'),
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment5'),
        VCAP::CloudController::IsolationSegmentModel.make(name: 'segment6')
      ]
    }

    it 'returns a paginated list of the isolation segments' do
      get '/v3/isolation_segments?per_page=2', nil, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'pagination'  => {
          'total_results' =>  6,
          'total_pages'   =>  3,
          'first'         =>  { 'href' => '/v3/isolation_segments?page=1&per_page=2' },
          'last'          =>  { 'href' => '/v3/isolation_segments?page=3&per_page=2' },
          'next'          =>  { 'href' => '/v3/isolation_segments?page=2&per_page=2' },
          'previous'      =>  nil
        },
        'resources'   =>  [
          {
            'guid'        =>  "#{models[0].guid}",
            'name'        =>  "#{models[0].name}",
            'created_at'  =>  iso8601,
            'updated_at'  =>  nil,
            'links'       =>  {
              'self'        =>  { 'href' => "/v3/isolation_segments/#{models[0].guid}" }
            }
          },
          {
            'guid'        =>  "#{models[1].guid}",
            'name'        =>  "#{models[1].name}",
            'created_at'  =>  iso8601,
            'updated_at'  =>  nil,
            'links'       =>  {
              'self'        =>  { 'href' => "/v3/isolation_segments/#{models[1].guid}" }
            }
          },
        ]
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'filters by names' do
      get "/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}", nil, user_header

      expected_pagination = {
        'total_results' =>  2,
        'total_pages'   =>  1,
        'first'         =>  { 'href' => "/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}&page=1&per_page=50" },
        'last'          =>  { 'href' => "/v3/isolation_segments?names=#{models[2].name}%2C#{models[4].name}&page=1&per_page=50" },
        'next'          =>  nil,
        'previous'      =>  nil
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'].map { |r| r['name'] }).to eq([models[2].name, models[4].name])
      expect(parsed_response['pagination']).to eq(expected_pagination)
    end

    it 'filters by guids' do
      get "/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}", nil, user_header

      expected_pagination = {
        'total_results' =>  2,
        'total_pages'   =>  1,
        'first'         =>  { 'href' => "/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}&page=1&per_page=50" },
        'last'          =>  { 'href' => "/v3/isolation_segments?guids=#{models[3].guid}%2C#{models[5].guid}&page=1&per_page=50" },
        'next'          =>  nil,
        'previous'      =>  nil
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'].map { |r| r['name'] }).to eq([models[3].name, models[5].name])
      expect(parsed_response['pagination']).to eq(expected_pagination)
    end
  end

  describe 'GET /v3/isolation_segments/:guid' do
    it 'describes the specified isolation segment' do
      isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.make(name: 'my_segment')

      get "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'name'       => 'my_segment',
        'guid'       => isolation_segment_model.guid,
        'created_at' => iso8601,
        'updated_at' => nil,
        'links'      => {
          'self' => { 'href' => "/v3/isolation_segments/#{isolation_segment_model.guid}" }
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'POST /v3/isolation_segments' do
    it 'creates an isolation segment' do
      create_request = {
        name:                  'my_segment'
      }

      post '/v3/isolation_segments', create_request, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(201)

      created_isolation_segment = VCAP::CloudController::IsolationSegmentModel.last
      expected_response = {
        'name'       => 'my_segment',
        'guid'       => created_isolation_segment.guid,
        'created_at' => iso8601,
        'updated_at' => nil,
        'links'      => {
          'self' => { 'href' => "/v3/isolation_segments/#{created_isolation_segment.guid}" }
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
