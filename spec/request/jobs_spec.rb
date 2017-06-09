require 'spec_helper'

RSpec.describe 'Jobs' do
  let(:user) { make_user }
  let(:user_headers) { headers_for(user, email: 'some_email@example.com', user_name: 'Mr. Freeze') }

  describe 'GET /v3/jobs/:guid' do
    it 'returns a json representation of the job with the requested guid' do
      operation = 'app.delete'
      job       = VCAP::CloudController::JobModel.make(
        state:     VCAP::CloudController::JobModel::COMPLETE_STATE,
        operation: operation,
      )
      job_guid = job.guid

      get "/v3/jobs/#{job_guid}", nil, user_headers

      expected_response = {
        'operation' => operation,
        'state'     => 'COMPLETE',
        'links'     => {
          'self' => { 'href' => "#{link_prefix}/v3/jobs/#{job_guid}" }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
