require 'spec_helper'

RSpec.describe 'Resource Matches' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) do
    headers_for(developer, user_name: 'roto')
  end
  let(:resource_pool_wrapper) { instance_double(VCAP::CloudController::ResourcePoolWrapper) }

  describe 'POST /v3/resource_matches' do
    before do
      allow(VCAP::CloudController::ResourcePoolWrapper).
        to receive(:new).
        and_return(resource_pool_wrapper)

      allow(resource_pool_wrapper).
        to receive(:call).
        and_return(MultiJson.dump([{
            'sha1' => '002d760bea1be268e27077412e11a320d0f164d3',
            'size' => 36,
            'fn' => '/path/to/filename',
            'mode' => '0755'
          }]))
    end

    let(:body) do
      {
        resources: [
          {
            checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
            size_in_bytes: 36,
            path: '/path/to/filename',
            mode: '0755'
          },
          {
            checksum: { value: 'a9993e364706816aba3e25717850c26c9cd0d89d' },
            size_in_bytes: 1,
            path: 'C:\\unknown\\file',
            mode: '0644'
          }
        ]
      }
    end

    it 'creates a resource match' do
      post '/v3/resource_matches', body.to_json, developer_headers

      expected_response = {
          'resources' => [
            {
              'checksum' => { 'value' => '002d760bea1be268e27077412e11a320d0f164d3' },
              'size_in_bytes' => 36,
              'path' => '/path/to/filename',
              'mode' => '0755'
            }
          ]
        }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'when resource_matching feature flag is disabled' do
      let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'resource_matching', enabled: false) }

      it 'returns zero matches' do
        post '/v3/resource_matches', body.to_json, developer_headers

        expected_response = {
          'resources' => []
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end
  end
end
