require 'spec_helper'
require 'membrane'
require 'json_message'
require 'cf_message_bus/mock_message_bus'

module VCAP::CloudController
  RSpec.describe LegacyBulk do
    let(:mbus) { CfMessageBus::MockMessageBus.new({}) }

    before do
      @bulk_user = 'bulk_user'
      @bulk_password = 'bulk_password'
    end

    describe '.register_subscription' do
      it 'should be able to discover credentials through message bus' do
        LegacyBulk.configure(TestConfig.config, mbus)

        expect(mbus).to receive(:subscribe).
          with('cloudcontroller.bulk.credentials.ng').
          and_yield('xxx', 'inbox')

        expect(mbus).to receive(:publish).with('inbox', anything) do |_, msg|
          expect(msg).to eq({
            'user'      => @bulk_user,
            'password'  => @bulk_password,
          })
        end

        LegacyBulk.register_subscription
      end
    end

    describe 'GET', '/bulk/apps' do
      before { 5.times { AppFactory.make(state: 'STARTED') } }

      it 'requires authentication' do
        get '/bulk/apps'
        expect(last_response.status).to eq(401)

        authorize 'bar', 'foo'
        get '/bulk/apps'
        expect(last_response.status).to eq(401)
      end

      describe 'with authentication' do
        before do
          authorize @bulk_user, @bulk_password
        end

        it 'ignores the batch_size parameter' do
          get '/bulk/apps', {
            'batch_size' => 'woopty_doo',
            'bulk_token' => '{}',
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['results']).not_to be_nil
        end

        it 'returns results in the response body' do
          get '/bulk/apps', {
            'bulk_token' => '{}'
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['results']).not_to be_nil
        end

        it 'returns results that are valid json' do
          get '/bulk/apps', {
            'bulk_token' => '{}'
          }

          expect(last_response.status).to eq(200)
          decoded_response['results'].each { |key, value|
            expect(value).to be_kind_of Hash
            expect(value['id']).not_to be_nil
            expect(value['version']).not_to be_nil
          }
        end

        it 'returns empty results on requests after the initial one' do
          get '/bulk/apps', {
            'bulk_token' => '{"id":1}'
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['results']).to be_empty
        end

        it 'does not include diego apps' do
          app = AppFactory.make(state: 'STARTED', diego: true)

          get '/bulk/apps', {
            'bulk_token' => '{}'
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['results']).to_not include(app.guid)
          expect(decoded_response['results'].size).to eq(5)
        end
      end
    end

    describe 'GET', '/bulk/counts' do
      it 'requires authentication' do
        get '/bulk/counts', { 'model' => 'user' }
        expect(last_response.status).to eq(401)
      end

      it 'returns the number of users' do
        4.times { User.make }
        authorize @bulk_user, @bulk_password
        get '/bulk/counts', { 'model' => 'user' }
        expect(decoded_response['counts']).to include('user' => kind_of(Integer))
        expect(decoded_response['counts']['user']).to eq(User.count)
      end
    end
  end
end
