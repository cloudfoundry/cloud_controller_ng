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
          expect(implementor.send(:basic_auth?, env)).to be true
        end

        it 'returns false when no authorization header is present' do
          expect(implementor.send(:basic_auth?, {})).to be false
        end

        it 'returns false for a Bearer token' do
          env = { 'HTTP_AUTHORIZATION' => 'Bearer some-token' }
          expect(implementor.send(:basic_auth?, env)).to be false
        end
      end
    end
  end
end
