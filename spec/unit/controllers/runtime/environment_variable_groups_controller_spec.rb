require 'spec_helper'

module VCAP::CloudController
  describe EnvironmentVariableGroupsController, type: :controller do
    describe 'GET /v2/config/environment_variable_groups/:name' do
      context 'when the name is not one of running, staging' do
        it 'returns a 404' do
          get '/v2/config/environment_variable_groups/flibble', '', admin_headers
          expect(last_response.status).to eq(404)
          expect(decoded_response['error_code']).to match(/CF-NotFound/)
        end
      end

      context 'and the name is running' do
        context 'whether or not the user is an admin' do
          it 'returns the json as a hash' do
            EnvironmentVariableGroup.make(name: 'running', environment_json: {
              'foo' => 'bar',
              'to all' => 'a good morrow'
            })

            get '/v2/config/environment_variable_groups/running', '{}', headers_for(User.make)
            expect(last_response.status).to eq(200)
            expect(decoded_response).to eq({
              'foo' => 'bar',
              'to all' => 'a good morrow'
            })
          end
        end
      end

      context 'and the name is staging' do
        context 'whether or not the user is an admin' do
          it 'returns the json as a hash' do
            EnvironmentVariableGroup.make(name: 'staging', environment_json: {
              'foo' => 'bar',
              'to all' => 'a good morrow'
            })

            get '/v2/config/environment_variable_groups/staging', '{}', headers_for(User.make)
            expect(last_response.status).to eq(200)
            expect(decoded_response).to eq({
              'foo' => 'bar',
              'to all' => 'a good morrow'
            })
          end
        end
      end
    end

    describe 'PUT /v2/config/environment_variable_groups/:name' do
      context 'when the name is not one of running, staging' do
        it 'returns a 404' do
          put '/v2/config/environment_variable_groups/flibble', '{}', admin_headers
          expect(last_response.status).to eq(404)
          expect(decoded_response['error_code']).to match(/CF-NotFound/)
        end
      end

      context 'when the name is staging' do
        context 'and the user is not an admin' do
          it 'returns a 403' do
            put '/v2/config/environment_variable_groups/staging', '{"foo": "bar"}', headers_for(User.make)
            expect(last_response.status).to eq(403)
          end
        end

        context 'and the user is an admin' do
          it 'updates the environment_json with the given hash' do
            put '/v2/config/environment_variable_groups/staging', '{"foo": "bar"}', admin_headers
            expect(last_response.status).to eq(200)
            expect(EnvironmentVariableGroup.staging.environment_json).to include({
              'foo' => 'bar'
            })

            expect(decoded_response).to eq({ 'foo' => 'bar' })
          end

          describe 'Validations' do
            context 'when the json is not valid' do
              it 'returns a 400' do
                put '/v2/config/environment_variable_groups/staging', 'jam sandwich', admin_headers
                expect(last_response.status).to eq(400)
                expect(decoded_response['error_code']).to eq('CF-MessageParseError')
                expect(decoded_response['description']).to match(/Request invalid due to parse error/)
              end

              it 'does not update the group' do
                EnvironmentVariableGroup.make(name: 'staging', environment_json: { 'foo' => 'bar' })
                put '/v2/config/environment_variable_groups/staging', 'jam sandwich', admin_headers
                expect(EnvironmentVariableGroup.staging.environment_json).to eq({ 'foo' => 'bar' })
              end
            end
          end
        end
      end

      context 'when the name is running' do
        context 'and the user is not an admin' do
          it 'returns a 403' do
            put '/v2/config/environment_variable_groups/running', '{"foo": "bar"}', headers_for(User.make)
            expect(last_response.status).to eq(403)
          end
        end

        context 'and the user is an admin' do
          it 'updates the environment_json with the given hash' do
            put '/v2/config/environment_variable_groups/running', '{"foo": "bar"}', admin_headers
            expect(last_response.status).to eq(200)
            expect(EnvironmentVariableGroup.running.environment_json).to include({
              'foo' => 'bar'
            })

            expect(decoded_response).to eq({ 'foo' => 'bar' })
          end

          describe 'Validations' do
            context 'when the json is not valid' do
              it 'returns a 400' do
                put '/v2/config/environment_variable_groups/running', 'jam sandwich', admin_headers
                expect(last_response.status).to eq(400)
                expect(decoded_response['error_code']).to eq('CF-MessageParseError')
                expect(decoded_response['description']).to match(/Request invalid due to parse error/)
              end

              it 'does not update the group' do
                EnvironmentVariableGroup.make(name: 'running', environment_json: { 'foo' => 'bar' })
                put '/v2/config/environment_variable_groups/running', 'jam sandwich', admin_headers
                expect(EnvironmentVariableGroup.running.environment_json).to eq({ 'foo' => 'bar' })
              end
            end
          end
        end
      end
    end
  end
end
