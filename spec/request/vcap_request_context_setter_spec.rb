require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'VCAP Request ID Middleware - User Agent' do
    let(:captured_values) { {} }

    before do
      allow_any_instance_of(CloudFoundry::Middleware::VcapRequestContextSetter).to receive(:call).and_wrap_original do |original_method, *args|
        env = args[0]
        result = original_method.call(*args)
        captured_values[:user_agent_during_request] = env['HTTP_USER_AGENT']
        captured_values[:request_id_during_request] = env['cf.request_id']

        result
      end
    end

    describe 'user agent and request id handling' do
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

    context 'telemetry' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }
      let(:user) { make_developer_for_space(space) }
      let(:user_agent) { 'cf/8.7.0 (go1.21.4; amd64 linux)' }
      let(:user_header) { headers_for(user, user_name: 'roto').merge('HTTP_USER_AGENT' => user_agent) }
      let(:logger_spy) { spy('logger') }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:buildpack) { VCAP::CloudController::Buildpack.make(stack: stack.name) }
      let(:create_request) do
        {
          name: 'my_app',
          lifecycle: {
            type: 'buildpack',
            data: {
              stack: buildpack.stack,
              buildpacks: [buildpack.name]
            }
          },
          relationships: {
            space: {
              data: {
                guid: space.guid
              }
            }
          }
        }
      end

      before do
        org.add_user(user)
        space.add_developer(user)
        allow(VCAP::CloudController::TelemetryLogger).to receive(:logger).and_return(logger_spy)
      end

      it 'includes user-agent in telemetry logs when making a request' do
        Timecop.freeze do
          post '/v3/apps', create_request.to_json, user_header

          parsed_response = Oj.load(last_response.body)
          app_guid = parsed_response['guid']

          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-app' => {
              'api-version' => 'v3',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid),
              'user-agent' => user_agent
            }
          }
          expect(logger_spy).to have_received(:info) do |actual_json|
            actual = Oj.load(actual_json)
            expect(actual).to eq(expected_json)
          end
          expect(last_response.status).to eq(201), last_response.body
        end
      end
    end
  end
end
