require 'spec_helper'
require 'mixins/user_id'

module CloudFoundry
  module Middleware
    RSpec.describe 'UserId mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::UserId }.new
      end

      describe '#get_user_id' do
        context 'when cf.user_guid is present' do
          it 'returns the user guid' do
            env = { 'cf.user_guid' => 'some-user-guid', 'PATH_INFO' => '/v3/apps' }
            expect(implementor.get_user_id(env)).to eq('some-user-guid')
          end
        end

        context 'when cf.user_guid is absent' do
          context 'when X-Forwarded-For is present' do
            let(:env) { { 'PATH_INFO' => '/v3/apps', 'HTTP_X_FORWARDED_FOR' => '1.2.3.4' } }
            let(:request_double) do
              headers = ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => '1.2.3.4' })
              instance_double(ActionDispatch::Request, headers: headers, ip: '10.0.0.1')
            end

            before { allow(ActionDispatch::Request).to receive(:new).with(env).and_return(request_double) }

            it 'returns the X-Forwarded-For IP' do
              expect(implementor.get_user_id(env)).to eq('1.2.3.4')
            end
          end

          context 'when X-Forwarded-For is absent' do
            let(:env) { { 'PATH_INFO' => '/v3/apps', 'REMOTE_ADDR' => '10.0.0.1' } }
            let(:request_double) do
              headers = ActionDispatch::Http::Headers.from_hash({})
              instance_double(ActionDispatch::Request, headers: headers, ip: '10.0.0.1')
            end

            before { allow(ActionDispatch::Request).to receive(:new).with(env).and_return(request_double) }

            it 'falls back to request.ip' do
              expect(implementor.get_user_id(env)).to eq('10.0.0.1')
            end
          end
        end
      end

      describe '#user_token?' do
        it 'returns true when cf.user_guid is set' do
          env = { 'cf.user_guid' => 'some-user-guid' }
          expect(implementor.send(:user_token?, env)).to be true
        end

        it 'returns false when cf.user_guid is absent' do
          expect(implementor.send(:user_token?, {})).to be false
        end

        it 'returns false when cf.user_guid is nil' do
          expect(implementor.send(:user_token?, { 'cf.user_guid' => nil })).to be false
        end
      end
    end
  end
end
