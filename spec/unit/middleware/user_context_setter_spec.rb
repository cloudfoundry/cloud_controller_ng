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
          expect(app).to receive(:call).ordered.and_return([200, {}, 'a body'])
          middleware.call(env)
        end
      end
    end
  end
end
