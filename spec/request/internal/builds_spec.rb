require 'spec_helper'

RSpec.describe 'Internal Builds Controller' do
  let(:build_model) { VCAP::CloudController::BuildModel.make(:kpack) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer, user_name: user_name, email: 'bob@loblaw.com') }
  let(:user_name) { 'bob the builder' }

  describe 'PATCH internal/builds/:guid' do
    context 'when the build exists' do
      before do
        patch "/v3/internal/builds/#{build_model.guid}", request.to_json, { 'CONTENT_TYPE' => 'application/json' }
      end

      context 'when the message is invalid' do
        let(:request) do
          {}
        end

        it 'returns 422 and renders the errors' do
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include('UnprocessableEntity')
          expect(last_response.body).to include('not a valid state')
        end
      end

      context 'when a build was successfully completed' do
        let(:request) do
          {
            state: 'STAGED'
          }
        end

        it 'returns 200' do
          expect(last_response.status).to eq(200)
        end

        it 'updates the state to STAGED' do
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
          expect(last_response.status).to eq(200)
        end

        it 'updates the state to FAILED' do
          parsed_response = MultiJson.load(last_response.body)

          expect(build_model.reload.state).to eq 'FAILED'
          expect(parsed_response['state']).to eq 'FAILED'
        end

        it 'updates the error' do
          parsed_response = MultiJson.load(last_response.body)

          expect(parsed_response['error']).to include 'failed to stage build'
        end
      end
    end

    context 'when the build does not exist' do
      let(:request) do
        {
          state: 'STAGED'
        }
      end

      before do
        patch '/v3/internal/builds/POTATO', request.to_json, { 'CONTENT_TYPE' => 'application/json' }
      end

      it 'returns a 404' do
        expect(last_response).to have_status_code(404)
      end
    end
  end
end
