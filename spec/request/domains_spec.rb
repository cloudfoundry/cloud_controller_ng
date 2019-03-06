require 'spec_helper'

RSpec.describe 'Domains Request' do
  describe 'POST /v3/domains' do
    context 'when not authenticated' do
      it 'returns 401' do
        params = {}
        headers = {}

        post '/v3/domains', params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/domains', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when successful' do
        let(:params) do
          {
            name: 'my-domain.biz',
            internal: true,
          }
        end

        it 'returns 201' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(201)

          domain = VCAP::CloudController::Domain.last

          expected_response = {
            'name' => params[:name],
            'internal' => params[:internal],
            'guid' => domain.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/domains/#{domain.guid}"
              }
            }
          }
          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end
  end
end
