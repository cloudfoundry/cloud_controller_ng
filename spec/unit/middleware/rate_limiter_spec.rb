require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      subject(:middleware) { described_class.new(app, default_limit) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:default_limit) { 100 }

      it 'adds a "X-RateLimit-Limit" header' do
        _, response_headers, _ = middleware.call({})
        expect(response_headers['X-RateLimit-Limit']).to eq('100')
      end
    end
  end
end
