require 'spec_helper'
require 'user_context_setter'

module CloudFoundry
  module Middleware
    RSpec.describe UserContextSetter do
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:security_context_configurer) { instance_double(VCAP::CloudController::Security::SecurityContextConfigurer, configure_user: nil) }
      let(:middleware) { UserContextSetter.new(app, security_context_configurer) }
      let(:env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => '/v3/apps' } }

      describe '#call' do
        it 'calls configure_user on the security context configurer' do
          middleware.call(env)
          expect(security_context_configurer).to have_received(:configure_user)
        end

        it 'passes the request to the app' do
          middleware.call(env)
          expect(app).to have_received(:call).with(env)
        end

        it 'returns the app response' do
          status, headers, body = middleware.call(env)
          expect(status).to eq(200)
          expect(headers).to eq({})
          expect(body).to eq('a body')
        end

        it 'calls configure_user before the app' do
          expect(security_context_configurer).to receive(:configure_user).ordered
          expect(app).to receive(:call).ordered
          middleware.call(env)
        end

        context 'when the database is unavailable' do
          before do
            allow(security_context_configurer).to receive(:configure_user).and_raise(Sequel::DatabaseConnectionError)
          end

          it 'returns a 503' do
            status, = middleware.call(env)
            expect(status).to eq(503)
          end

          it 'sets the Content-Type header' do
            _, headers, = middleware.call(env)
            expect(headers['Content-Type']).to eq('application/json')
          end

          context 'when the path is /v3/*' do
            it 'returns a v3 error body' do
              _, _, body = middleware.call(env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first).to include(
                'title' => 'CF-ServiceUnavailable',
                'detail' => 'Database connection failure'
              )
            end
          end

          context 'when the path is /v2/*' do
            let(:env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => '/v2/apps' } }

            it 'returns a v2 error body' do
              _, _, body = middleware.call(env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'error_code' => 'CF-ServiceUnavailable',
                'description' => 'Database connection failure'
              )
            end
          end

          context 'when the path is /internal/*' do
            let(:env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => '/internal/v4/droplets/some-guid/some-checksum/download' } }

            it 'returns a v2-format error body' do
              _, _, body = middleware.call(env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'error_code' => 'CF-ServiceUnavailable',
                'description' => 'Database connection failure'
              )
            end
          end

          context 'when a general database error occurs (e.g. DB read-only during failover)' do
            before do
              allow(security_context_configurer).to receive(:configure_user).and_raise(Sequel::DatabaseError)
            end

            it 'returns a 503' do
              status, = middleware.call(env)
              expect(status).to eq(503)
            end
          end

          context 'when the database disconnects' do
            before do
              allow(security_context_configurer).to receive(:configure_user).and_raise(Sequel::DatabaseDisconnectError)
            end

            it 'returns a 503' do
              status, = middleware.call(env)
              expect(status).to eq(503)
            end
          end
        end
      end
    end
  end
end
