require 'spec_helper'
require 'mixins/too_many_requests'

module CloudFoundry
  module Middleware
    RSpec.describe 'TooManyRequests mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::TooManyRequests }.new
      end

      let(:v2_env) { { 'PATH_INFO' => '/v2/apps' } }
      let(:v3_env) { { 'PATH_INFO' => '/v3/apps' } }

      describe '#too_many_requests!' do
        it 'returns a 429 status' do
          status, = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1)
          expect(status).to eq(429)
        end

        it 'sets the Retry-After header' do
          _, headers, = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1)
          expect(headers['Retry-After']).to eq('1')
        end

        it 'sets Content-Type to text/plain' do
          _, headers, = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1)
          expect(headers['Content-Type']).to eq('text/plain; charset=utf-8')
        end

        it 'sets Content-Length matching the body size' do
          _, headers, body = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1)
          expect(headers['Content-Length']).to eq(body.first.bytesize.to_s)
        end

        it 'merges extra_headers without overriding standard headers' do
          _, headers, = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1,
                                                                                    extra_headers: { 'X-RateLimit-Limit' => '100' })
          expect(headers['X-RateLimit-Limit']).to eq('100')
          expect(headers['Retry-After']).to eq('1')
        end

        context 'when the path is /v2' do
          it 'formats the body as a v2 error' do
            _, _, body = implementor.too_many_requests!(v2_env, 'RateLimitExceeded', retry_after: 1)
            json = Oj.load(body.first)
            expect(json).to include('error_code' => 'CF-RateLimitExceeded')
          end
        end

        context 'when the path is /v3' do
          it 'formats the body as a v3 error' do
            _, _, body = implementor.too_many_requests!(v3_env, 'RateLimitExceeded', retry_after: 1)
            json = Oj.load(body.first)
            expect(json['errors'].first).to include('title' => 'CF-RateLimitExceeded')
          end
        end
      end
    end
  end
end
