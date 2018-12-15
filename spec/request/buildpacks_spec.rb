require 'spec_helper'

RSpec.describe 'buildpacks' do
  describe 'POST /v3/buildpacks' do
    context 'when not authenticated' do
      it 'returns 401' do
        params = {}
        headers = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when successful' do
        let(:stack) { VCAP::CloudController::Stack.make }
        let(:params) do
          {
            name: 'the-r3al_Name',
            stack: stack.name,
            position: 2,
            enabled: false,
            locked: true,
          }
        end

        it 'returns 201' do
          post '/v3/buildpacks', params.to_json, headers

          expect(last_response.status).to eq(201)
        end

        it 'returns the newly-created buildpack resource' do
          post '/v3/buildpacks', params.to_json, headers

          buildpack = VCAP::CloudController::Buildpack.last

          expected_response = {
            'name' => params[:name],
            'stack' => params[:stack],
            'position' => params[:position],
            'enabled' => params[:enabled],
            'locked' => params[:locked],
            'guid' => buildpack.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
              }
            }
          }
          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end
  end
end
