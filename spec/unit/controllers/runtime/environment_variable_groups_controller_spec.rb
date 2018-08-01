require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EnvironmentVariableGroupsController do
    describe 'GET /v2/config/environment_variable_groups/:name' do
      context 'when the name is not one of running, staging' do
        it 'returns a 404' do
          set_current_user_as_admin

          get '/v2/config/environment_variable_groups/flibble'
          expect(last_response.status).to eq(404)
          expect(decoded_response['error_code']).to match(/CF-NotFound/)
        end
      end

      context 'and the name is running' do
        context 'whether or not the user is an admin' do
          it 'returns the json as a hash' do
            set_current_user(User.make)

            group = EnvironmentVariableGroup.running
            group.environment_json = {
              'foo' => 'bar',
              'to all' => 'a good morrow'
            }
            group.save

            get '/v2/config/environment_variable_groups/running'
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
            set_current_user(User.make)

            group = EnvironmentVariableGroup.staging
            group.environment_json = {
              'foo' => 'bar',
              'to all' => 'a good morrow'
            }
            group.save

            get '/v2/config/environment_variable_groups/staging'
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
          set_current_user_as_admin
          put '/v2/config/environment_variable_groups/flibble', '{}'
          expect(last_response.status).to eq(404)
          expect(decoded_response['error_code']).to match(/CF-NotFound/)
        end
      end

      context 'when the name is staging' do
        context 'and the user is not an admin' do
          it 'returns a 403' do
            set_current_user(User.make)

            put '/v2/config/environment_variable_groups/staging', '{"foo": "bar"}'
            expect(last_response.status).to eq(403)
          end
        end

        context 'and the user is an admin' do
          it 'updates the environment_json with the given hash' do
            set_current_user_as_admin

            put '/v2/config/environment_variable_groups/staging', '{"foo": "bar"}'
            expect(last_response.status).to eq(200)
            expect(EnvironmentVariableGroup.staging.environment_json).to include({
              'foo' => 'bar'
            })

            expect(decoded_response).to eq({ 'foo' => 'bar' })
          end

          describe 'Validations' do
            context 'when the json is not valid' do
              it 'returns a 400' do
                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/staging', 'jam sandwich'
                expect(last_response.status).to eq(400)
                expect(decoded_response['error_code']).to eq('CF-MessageParseError')
                expect(decoded_response['description']).to match(/Request invalid due to parse error/)
              end

              it 'does not update the group' do
                group = EnvironmentVariableGroup.staging
                group.environment_json = { 'foo' => 'bar' }
                group.save

                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/staging', 'jam sandwich'

                expect(EnvironmentVariableGroup.staging.environment_json).to eq({ 'foo' => 'bar' })
              end
            end
          end
        end
      end

      context 'when the name is running' do
        context 'and the user is not an admin' do
          it 'returns a 403' do
            set_current_user(User.make)

            put '/v2/config/environment_variable_groups/running', '{"foo": "bar"}'
            expect(last_response.status).to eq(403)
          end
        end

        context 'and the user is an admin' do
          it 'updates the environment_json with the given hash' do
            set_current_user_as_admin
            put '/v2/config/environment_variable_groups/running', '{"foo": "bar"}'
            expect(last_response.status).to eq(200)
            expect(EnvironmentVariableGroup.running.environment_json).to include({
              'foo' => 'bar'
            })

            expect(decoded_response).to eq({ 'foo' => 'bar' })
          end

          describe 'Validations' do
            context 'when the json is not valid' do
              let(:req_body) { 'jam sandwich' }

              it 'returns a 400' do
                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/running', req_body
                expect(last_response.status).to eq(400)
                expect(decoded_response['error_code']).to eq('CF-MessageParseError')
                expect(decoded_response['description']).to match(/Request invalid due to parse error/)
              end

              it 'does not update the group' do
                group = EnvironmentVariableGroup.running
                group.environment_json = { 'foo' => 'bar' }
                group.save

                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/running', req_body
                expect(EnvironmentVariableGroup.running.environment_json).to eq({ 'foo' => 'bar' })
              end
            end

            context 'when the json is null' do
              let(:req_body) { 'null' }

              it 'returns a 400' do
                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/running', req_body
                expect(last_response.status).to eq(400)
                expect(decoded_response['error_code']).to eq('CF-EnvironmentVariableGroupInvalid')
                expect(decoded_response['description']).to match(/Cannot be 'null'. You may want to try empty object '{}' to clear the group./)
              end

              it 'does not update the group' do
                group = EnvironmentVariableGroup.running
                group.environment_json = { 'foo' => 'bar' }
                group.save

                set_current_user_as_admin
                put '/v2/config/environment_variable_groups/running', req_body
                expect(EnvironmentVariableGroup.running.environment_json).to eq({ 'foo' => 'bar' })
              end
            end
          end
        end
      end
    end
  end
end
