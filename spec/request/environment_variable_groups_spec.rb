require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Environment group variables' do
  before do
    VCAP::CloudController::EnvironmentVariableGroup.find(name: 'running').update(environment_json: { 'foo' => 'burger_king', 'bar' => 'sonic' })
    VCAP::CloudController::EnvironmentVariableGroup.find(name: 'staging').update(environment_json: { 'foo' => 'wendys', 'baz' => 'whitecastle' })
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:admin_header) { admin_headers_for(user) }

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
            'foo' => 'burger_king',
            'bar' => 'sonic'
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/running"
            }
          }
        }
      )
    end

    it 'gets the environment variables for the staging group' do
      get '/v3/environment_variable_groups/staging', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to match_json_response(
        {
          'updated_at' => iso8601,
          'name' => 'staging',
          'var' => {
            'foo' => 'wendys',
            'baz' => 'whitecastle'
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

  describe 'PATCH /v3/environment_variable_groups/:name' do
    let(:params) do
      {
        var: {
          foo: 'in-n-out',
          boo: 'mcdonalds',
          bar: nil
        }
      }
    end

    it 'updates the environment variables for the running group' do
      patch '/v3/environment_variable_groups/running', params.to_json, admin_header
      puts last_response.body
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to match_json_response(
        {
          'updated_at' => iso8601,
          'name' => 'running',
          'var' => {
            'foo' => 'in-n-out',
            'boo' => 'mcdonalds',
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/running"
            }
          }
        }
      )
    end

    it 'updates the environment variables for the staging group' do
      patch '/v3/environment_variable_groups/staging', params.to_json, admin_header
      puts last_response.body
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to match_json_response(
        {
          'updated_at' => iso8601,
          'name' => 'staging',
          'var' => {
            'foo' => 'in-n-out',
            'boo' => 'mcdonalds',
            'baz' => 'whitecastle'
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/staging"
            }
          }
        }
      )
    end

    context 'when the user logged in' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }
      let(:api_call) { lambda { |user_headers| patch '/v3/environment_variable_groups/staging', params.to_json, user_headers } }

      let(:env_group_json) do
        {
          'updated_at' => iso8601,
          'name' => 'staging',
          'var' => {
            'foo' => 'in-n-out',
            'boo' => 'mcdonalds',
            'baz' => 'whitecastle'
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/environment_variable_groups/staging"
            }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 200, response_object: env_group_json }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when request input message is invalid' do
      let(:request_with_invalid_input) do
        {
          disallowed_key: 'val'
        }
      end

      it 'returns a 422' do
        patch '/v3/environment_variable_groups/running', request_with_invalid_input.to_json, admin_header

        expect(last_response.status).to eq(422)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        patch '/v3/environment_variable_groups/running', params.to_json, base_json_headers

        expect(last_response.status).to eq(401)
      end
    end
  end
end
