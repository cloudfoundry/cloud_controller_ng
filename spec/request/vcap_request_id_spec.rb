require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'VCAP Request ID Middleware - User Agent' do
    let(:captured_values) { {} }

    before do
      allow_any_instance_of(CloudFoundry::Middleware::VcapRequestId).to receive(:call).and_wrap_original do |original_method, *args|
        env = args[0]
        result = original_method.call(*args)
        captured_values[:user_agent_during_request] = env['HTTP_USER_AGENT']
        captured_values[:request_id_during_request] = env['cf.request_id']

        result
      end
    end

    describe 'user agentand request id handling' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:user)  { make_developer_for_space(space) }
      let(:request_id) { 'test-request-123' }
      let(:user_agent) { 'cf/8.7.0 (go1.21.4; amd64 linux)' }
      let(:user_headers) do
        headers_for(user, user_name: 'roto').merge('HTTP_USER_AGENT' => user_agent)
      end

      context 'when User-Agent header is provided' do
        it 'sets VCAP::Request.user_agent during the request' do
          get '/v3/spaces', nil, user_headers
          expect(last_response.status).to eq(200)
          expect(captured_values[:user_agent_during_request]).to eq(user_agent)
          expect(captured_values[:request_id_during_request]).to be_present
          # After the request completes, user_agent should be nil
          expect(::VCAP::Request.user_agent).to be_nil
        end
      end

      context 'when User-Agent header and HTTP_X_VCAP_REQUEST_ID are provided' do
        it 'sets VCAP::Request.user_agent and HTTP_X_VCAP_REQUEST_ID during the request' do
          get '/v3/spaces', nil, user_headers.merge('HTTP_X_VCAP_REQUEST_ID' => request_id)
          expect(last_response.status).to eq(200)
          expect(captured_values[:user_agent_during_request]).to eq(user_agent)
          expect(captured_values[:request_id_during_request]).to include(request_id)
          expect(last_response.headers['X-VCAP-Request-ID']).to include(request_id)
          # After the request completes, user_agent and current_id should be nil
          expect(::VCAP::Request.user_agent).to be_nil
          expect(::VCAP::Request.current_id).to be_nil
        end
      end
    end
  end
end
