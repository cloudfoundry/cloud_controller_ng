require 'spec_helper'

RSpec.describe 'IsolationSegmentModels' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }

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
          'self' => { 'href' => "/v3/isolation_segments/#{created_isolation_segment.guid}" },
          'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{created_isolation_segment.guid}" }
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/isolation_segments/:guid' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }

    context 'as an admin' do
      it 'returns the requested isolation segment' do
        get "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'name'       => isolation_segment_model.name,
          'guid'       => isolation_segment_model.guid,
          'created_at' => iso8601,
          'updated_at' => nil,
          'links'      => {
            'self' => { 'href' => "/v3/isolation_segments/#{isolation_segment_model.guid}" },
            'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{isolation_segment_model.guid}" }
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    context 'when a user has read permissions for a space associated to an isolation_segment' do
      let(:user_header) { headers_for(user) }

      before do
        space.isolation_segment_guid = isolation_segment_model.guid
        space.save
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
          'updated_at' => nil,
          'links'      => {
            'self' => { 'href' => "/v3/isolation_segments/#{isolation_segment_model.guid}" },
            'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{isolation_segment_model.guid}" }
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end
  end

  describe 'GET /v3/isolation_segments' do
    it 'retruns the seeded isolation segment' do
        get '/v3/isolation_segments', nil, user_header

        expect(last_response.status).to eq 200
        prased_response = MultiJson.load(last_response.body)

        shared_guid = VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID

        expected_response = {
          'name'       => 'name-1',
          'guid'       => shared_guid,
          'created_at' => iso8601,
          'updated_at' => nil,
          'links'      => {
            'self' => { 'href' => "/v3/isolation_segments/#{shared_guid}" },
            'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{shared_guid}" }
          }
        }
    end

    context 'when there are multiple isolation segments' do
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

      # We do not account for the first isolation segment as it is a seed in the database.
      it 'returns a paginated list of the isolation segments' do
        get '/v3/isolation_segments?per_page=2&page=2', nil, user_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'pagination' => {
            'total_results' =>  7,
            'total_pages'   =>  4,
            'first'         =>  { 'href' => '/v3/isolation_segments?page=1&per_page=2' },
            'last'          =>  { 'href' => '/v3/isolation_segments?page=4&per_page=2' },
            'next'          =>  { 'href' => '/v3/isolation_segments?page=3&per_page=2' },
            'previous'      =>  { 'href' => '/v3/isolation_segments?page=1&per_page=2' }
          },
          'resources' => [
            {
              'guid'        =>  models[1].guid.to_s,
              'name'        =>  models[1].name.to_s,
              'created_at'  =>  iso8601,
              'updated_at'  =>  nil,
              'links'       =>  {
                'self' => { 'href' => "/v3/isolation_segments/#{models[1].guid}" },
                'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{models[1].guid}" }
              }
            },
            {
              'guid'        =>  models[2].guid.to_s,
              'name'        =>  models[2].name.to_s,
              'created_at'  =>  iso8601,
              'updated_at'  =>  nil,
              'links'       =>  {
                'self' => { 'href' => "/v3/isolation_segments/#{models[2].guid}" },
                'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{models[2].guid}" }
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

      context 'when the user is not an admin' do
        let(:user_header) { headers_for(user) }

        before do
          space.isolation_segment_guid = models[1].guid
          space.save
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'filters by associated spaces to which the user has access' do
          get '/v3/isolation_segments', nil, user_header

          parsed_response = MultiJson.load(last_response.body)
          expect(last_response.status).to eq(200)

          expected_response = {
            'pagination' => {
              'total_results' =>  1,
              'total_pages'   =>  1,
              'first'         =>  { 'href' => '/v3/isolation_segments?page=1&per_page=50' },
              'last'          =>  { 'href' => '/v3/isolation_segments?page=1&per_page=50' },
              'next'          =>  nil,
              'previous'      =>  nil
            },
            'resources' => [
              {
                'guid'        =>  models[1].guid.to_s,
                'name'        =>  models[1].name.to_s,
                'created_at'  =>  iso8601,
                'updated_at'  =>  nil,
                'links'       =>  {
                  'self' => { 'href' => "/v3/isolation_segments/#{models[1].guid}" },
                  'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{models[1].guid}" }
                }
              },
            ]
          }

          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end
  end

  describe 'PUT /v3/isolation_segments/:guid' do
    it 'updates the specified isolation segment' do
      isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.make(name: 'my_segment')

      update_request = {
        name:                  'your_segment'
      }

      expected_response = {
        'name'       => 'your_segment',
        'guid'       => isolation_segment_model.guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links'      => {
          'self' => { 'href' => "/v3/isolation_segments/#{isolation_segment_model.guid}" },
          'spaces' => { 'href' => "/v2/spaces?q=isolation_segment_guid:#{isolation_segment_model.guid}" }
        }
      }

      put "/v3/isolation_segments/#{isolation_segment_model.guid}", update_request, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'DELETE /v3/isolation_segments/:guid' do
    it 'deletes the specified isolation segment' do
      isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.make(name: 'my_segment')

      delete "/v3/isolation_segments/#{isolation_segment_model.guid}", nil, user_header
      expect(last_response.status).to eq(204)
    end
  end
end
