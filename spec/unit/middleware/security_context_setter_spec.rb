require 'spec_helper'
require 'security_context_setter'

module CloudFoundry
  module Middleware
    RSpec.describe SecurityContextSetter do
      let(:middleware) { described_class.new(app, security_context_configurer) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:env) do
        {
          'HTTP_AUTHORIZATION' => 'auth-token'
        }
      end
      let(:token_decoder) { instance_double(VCAP::UaaTokenDecoder) }
      let(:security_context_configurer) { VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder) }

      describe '#call' do
        let(:token_information) { { 'user_id' => 'user-id-1', 'user_name' => 'mrpotato' } }

        before do
          allow(token_decoder).to receive(:decode_token).with('auth-token').and_return(token_information)
        end

        it 'sets the security context token and the raw token' do
          middleware.call(env)
          expect(VCAP::CloudController::SecurityContext.token).to eq(token_information)
          expect(VCAP::CloudController::SecurityContext.auth_token).to eq('auth-token')
        end

        it 'sets user name and guid on the env' do
          middleware.call(env)

          expect(app).to have_received(:call) do |passed_env|
            expect(passed_env['cf.user_guid']).to eq('user-id-1')
            expect(passed_env['cf.user_name']).to eq('mrpotato')
          end
        end
      end
    end
  end
end
