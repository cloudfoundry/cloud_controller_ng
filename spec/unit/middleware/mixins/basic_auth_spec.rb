require 'spec_helper'
require 'mixins/basic_auth'

module CloudFoundry
  module Middleware
    RSpec.describe 'BasicAuth mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::BasicAuth }.new
      end

      describe '#basic_auth?' do
        it 'returns true when a Basic auth header is present' do
          env = { 'HTTP_AUTHORIZATION' => 'Basic ' + Base64.encode64('user:pass').strip }
          expect(implementor).to be_basic_auth(env)
        end

        it 'returns false when no authorization header is present' do
          expect(implementor).not_to be_basic_auth({})
        end

        it 'returns false for a Bearer token' do
          env = { 'HTTP_AUTHORIZATION' => 'Bearer some-token' }
          expect(implementor).not_to be_basic_auth(env)
        end
      end
    end
  end
end
