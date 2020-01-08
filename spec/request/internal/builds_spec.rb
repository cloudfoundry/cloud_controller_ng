require 'spec_helper'
require 'permissions_spec_helper'

RSpec.describe 'Internal Builds Controller' do
  let(:build_model) { VCAP::CloudController::BuildModel.make(:kpack) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:content_type_header) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers) { content_type_header.merge(admin_header) }
  let(:user_name) { 'bob the builder' }
  let(:request) do
    {
      state: 'STAGED'
    }
  end

  describe 'PATCH internal/builds/:guid' do
    context 'when the build exists' do
      context 'when the message is invalid' do
        let(:request) do
          {}
        end

        it 'returns 422 and renders the errors' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include('UnprocessableEntity')
          expect(last_response.body).to include('not a valid state')
        end
      end

      context 'when a build was successfully completed' do
        it 'returns 200' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          expect(last_response.status).to eq(200)
        end

        it 'updates the state to STAGED' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          parsed_response = MultiJson.load(last_response.body)

          expect(build_model.reload.state).to eq 'STAGED'
          expect(parsed_response['state']).to eq 'STAGED'
        end
      end

      context 'when a build failed to complete' do
        let(:request) do
          {
            state: 'FAILED',
            error: 'failed to stage build'
          }
        end

        it 'returns 200' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          expect(last_response.status).to eq(200)
        end

        it 'updates the state to FAILED' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          parsed_response = MultiJson.load(last_response.body)

          expect(build_model.reload.state).to eq 'FAILED'
          expect(parsed_response['state']).to eq 'FAILED'
        end

        it 'updates the error' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, headers
          parsed_response = MultiJson.load(last_response.body)

          expect(parsed_response['error']).to include 'failed to stage build'
        end
      end

      context 'when the user isnt logged in' do
        it 'returns a 401' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, content_type_header
          expect(last_response).to have_status_code(401)
        end
      end

      context 'when the user doesnt have the right roles' do
        it 'returns a 403' do
          patch "/v3/internal/builds/#{build_model.guid}", request.to_json, content_type_header.merge(headers_for(user))
          expect(last_response).to have_status_code(403)
        end
      end
    end

    context 'when the build does not exist' do
      it 'returns a 404' do
        patch '/v3/internal/builds/POTATO', request.to_json, headers
        expect(last_response).to have_status_code(404)
      end
    end
  end
end
