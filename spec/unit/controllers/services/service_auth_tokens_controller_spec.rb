require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthTokensController, :services do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:label) }
      it { expect(described_class).to be_queryable_by(:provider) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          label: { type: 'string', required: true },
          provider: { type: 'string', required: true },
          token: { type: 'string', required: true }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          label: { type: 'string' },
          provider: { type: 'string' },
          token: { type: 'string' }
        })
      end
    end

    describe 'GET', '/v2/service_auth_tokens' do
      it 'adds the X-Cf-Warning with the right message to the response' do
        get '/v2/service_auth_tokens', {}, admin_headers
        expect(last_response.status).to eq 200
        expect(last_response).to have_warning_message(VCAP::CloudController::ServiceAuthTokensController::DEPRECATION_MESSAGE)
      end
    end

    describe 'CREATE', '/v2/service_auth_tokens' do
      it 'adds the X-Cf-Warning with the right message to the response' do
        req = {
          label: 'some-label',
          provider: 'some-provider',
          token: 'some-token'
        }.to_json

        post '/v2/service_auth_tokens', req, admin_headers
        expect(last_response.status).to eq 201
        expect(last_response).to have_warning_message(VCAP::CloudController::ServiceAuthTokensController::DEPRECATION_MESSAGE)
      end
    end

    describe 'UPDATE', '/v2/service_auth_tokens/:service_auth_token_guid' do
      let(:token) { ServiceAuthToken.make }

      it 'adds the X-Cf-Warning with the right message to the response' do
        req = {
          label: 'some-label',
          provider: 'some-provider',
          token: 'some-token'
        }.to_json

        put "/v2/service_auth_tokens/#{token.guid}", req, admin_headers
        expect(last_response.status).to eq 201
        expect(last_response).to have_warning_message(VCAP::CloudController::ServiceAuthTokensController::DEPRECATION_MESSAGE)
      end
    end

    describe 'DELETE', '/v2/service_auth_tokens/:service_auth_token_guid' do
      let(:token) { ServiceAuthToken.make }

      it 'adds the X-Cf-Warning with the right message to the response' do
        delete "/v2/service_auth_tokens/#{token.guid}", {}, admin_headers
        expect(last_response.status).to eq 204
        expect(last_response).to have_warning_message(VCAP::CloudController::ServiceAuthTokensController::DEPRECATION_MESSAGE)
      end
    end

    describe 'audit events' do
      it 'logs audit.service_auth_token.delete-request when deleting a service auth token' do
        service_auth_token = ServiceAuthToken.make
        service_auth_token_guid = service_auth_token.guid
        delete "/v2/service_auth_tokens/#{service_auth_token_guid}", '', json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(type: 'audit.service_auth_token.delete-request', actee: service_auth_token_guid)
        expect(event).not_to be_nil
        expect(event.actee).to eq(service_auth_token_guid)
        expect(event.actee_name).to eq(service_auth_token.label)
        expect(event.organization_guid).to eq('')
        expect(event.space_guid).to eq('')
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
      end
    end
  end
end
