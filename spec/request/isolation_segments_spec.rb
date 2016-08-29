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
        'name'                    => 'my_segment',
        'guid'                    => created_isolation_segment.guid,
        'created_at'              => iso8601,
        'updated_at'              => nil
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
