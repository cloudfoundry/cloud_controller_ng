require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Users Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }
  let(:user_header) { headers_for(user, scopes: []) }
  let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
  let(:other_user_guid) { 'some-user-guid' }

  before do
    VCAP::CloudController::User.dataset.destroy # this will clean up the seeded test users
    allow(VCAP::CloudController::UaaClient).to receive(:new).and_return(uaa_client)
  end

  describe 'POST /v3/users' do
    let(:params) do
      {
        guid: other_user_guid,
      }
    end

    describe 'when creating a user that does not exist in uaa' do
      before do
        allow(uaa_client).to receive(:usernames_for_ids).and_return({})
      end

      let(:api_call) { lambda { |user_headers| post '/v3/users', params.to_json, user_headers } }

      let(:user_json) do
        {
          guid: params[:guid],
          created_at: iso8601,
          updated_at: iso8601,
          username: nil,
          presentation_name: nil,
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: user_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when creating a user that exists in uaa' do
      before do
        allow(uaa_client).to receive(:usernames_for_ids).and_return({ other_user_guid => 'bob-mcjames' })
      end

      let(:api_call) { lambda { |user_headers| post '/v3/users', params.to_json, user_headers } }

      let(:user_json) do
        {
          guid: params[:guid],
          created_at: iso8601,
          updated_at: iso8601,
          username: 'bob-mcjames',
          presentation_name: 'bob-mcjames',
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: user_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/users', params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/users', params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the params are invalid' do
      let(:headers) { set_user_with_header_as_role(role: 'admin') }

      context 'when provided invalid arguments' do
        let(:params) do
          {
            guid: 555
          }
        end

        it 'returns 422' do
          post '/v3/users', params.to_json, headers

          expect(last_response.status).to eq(422)

          expected_err = [
            'Guid must be a string',
          ]
          expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
        end
      end

      context 'with an existing user' do
        let!(:existing_user) { VCAP::CloudController::User.make }

        let(:params) do
          {
            guid: existing_user.guid,
          }
        end

        it 'returns 422' do
          post '/v3/users', params.to_json, headers

          expect(last_response.status).to eq(422)

          expect(parsed_response['errors'][0]['detail']).to eq "User with guid '#{existing_user.guid}' already exists."
        end
      end
    end
  end
end
