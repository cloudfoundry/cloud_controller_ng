require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) { RateLimiter.new(app, default_limit) }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:default_limit) { 100 }

      it 'adds a "X-RateLimit-Limit" header' do
        _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
        expect(response_headers['X-RateLimit-Limit']).to eq('100')
      end

      it 'adds a "X-RateLimit-Remaining" header per user' do
        _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
        expect(response_headers['X-RateLimit-Remaining']).to eq('99')
        _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
        expect(response_headers['X-RateLimit-Remaining']).to eq('98')

        _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-2'})
        expect(response_headers['X-RateLimit-Remaining']).to eq('99')
      end

      it 'does not do anything when the user is not logged it' do
        _, response_headers, _ = middleware.call({})
        expect(response_headers['X-RateLimit-Remaining']).to be_nil
      end

      context 'when reaching zero' do
        let(:default_limit) { 1 }

        it 'does not go lower than zero' do
          _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
          _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
        end
      end

      context 'with multiple servers' do
        let(:other_middleware) { RateLimiter.new(app, default_limit) }

        it 'shares request count between servers' do
          _, response_headers, _ = middleware.call({'cf.user_guid' => 'user-id-1'})
          expect(response_headers['X-RateLimit-Remaining']).to eq('99')
          _, response_headers, _ = other_middleware.call({'cf.user_guid' => 'user-id-1'})
          expect(response_headers['X-RateLimit-Remaining']).to eq('98')
        end
      end
    end
  end
end
