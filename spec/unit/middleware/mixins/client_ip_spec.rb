require 'spec_helper'
require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    RSpec.describe 'ClientIp mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::ClientIp }.new
      end

      describe 'when the request has a "HTTP_X_FORWARDED_FOR" header' do
        it 'returns the first ip in the header' do
          headers = ActionDispatch::Http::Headers.new({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip, another_ip' })
          request = instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip')

          expect(implementor.client_ip(request)).to eq('forwarded_ip')
        end
      end

      describe 'when the request does NOT have a "HTTP_X_FORWARDED_FOR" header' do
        it 'returns the request ip' do
          headers = ActionDispatch::Http::Headers.new({ 'X_HEADERS' => 'nope' })
          request = instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip')

          expect(implementor.client_ip(request)).to eq('proxy-ip')
        end
      end
    end
  end
end
