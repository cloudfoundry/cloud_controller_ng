require 'spec_helper'

RSpec.describe 'Environment group variables' do
  before do
    VCAP::CloudController::EnvironmentVariableGroup.find(name: 'running').update(environment_json: { 'foo' => 'burger_king' })
    VCAP::CloudController::EnvironmentVariableGroup.find(name: 'staging').update(environment_json: { 'foo' => 'wendys' })
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }

  describe 'GET /v3/environment_variable_groups/:name' do
    it 'gets the environment variables for the running group' do
      get '/v3/environment_variable_groups/running', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to match_json_response(
        {
          'updated_at' => iso8601,
          'name' => 'running',
          'var' => {
            'foo' => 'burger_king'
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/running"
            }
          }
        }
      )
    end

    it 'gets the environment variables for the running group' do
      get '/v3/environment_variable_groups/staging', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to match_json_response(
        {
          'updated_at' => iso8601,
          'name' => 'staging',
          'var' => {
            'foo' => 'wendys'
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/staging"
            }
          }
        }
      )
    end

    context 'the name is not staging or running' do
      it 'gets the environment variables for the running group' do
        get '/v3/environment_variable_groups/purple', nil, user_header

        expect(last_response.status).to eq(404)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['errors'][0]['detail']).to include('Environment variable group not found')
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/environment_variable_groups/staging', nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end
end
