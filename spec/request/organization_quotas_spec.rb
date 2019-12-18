require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'organization_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user') }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }
    describe 'POST /v3/organization_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/organization_quotas', params.to_json, user_headers } }

      let(:params) do
        {
        'name': 'org1',
        }
      end

      let(:organization_quota_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: organization_quota_json
        }
        h.freeze
      end

      it 'creates a organization_quota' do
        expect {
          api_call.call(admin_header)
        }.to change {
          QuotaDefinition.count
        }.by 1
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/organization_quotas', params.to_json, base_json_headers
          expect(last_response).to have_status_code(401)
        end
      end

      context 'when the params are invalid' do
        let(:headers) { set_user_with_header_as_role(role: 'admin') }

        context 'when provided invalid arguments' do
          let(:params) do
            {
              name: 555
            }
          end

          it 'returns 422' do
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)

            expected_err = [
              'Name must be a string',
            ]
            expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
          end
        end

        context 'with a pre-existing name' do
          let(:params) do
            {
              name: 'double-trouble',
            }
          end

          it 'returns 422' do
            post '/v3/organization_quotas', params.to_json, headers
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message("Organization Quota 'double-trouble' already exists.")
          end
        end
      end
    end
  end
end
