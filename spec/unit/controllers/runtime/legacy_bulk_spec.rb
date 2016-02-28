require 'spec_helper'
require 'membrane'
require 'json_message'
require 'cf_message_bus/mock_message_bus'

module VCAP::CloudController
  describe LegacyBulk do
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
      before { 5.times { AppFactory.make(state: 'STARTED', package_state: 'STAGED') } }

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

        it 'requires a token in query string' do
          get '/bulk/apps'
          expect(last_response.status).to eq(400)
        end

        it 'returns nil bulk_token for the initial request' do
          get '/bulk/apps'
          expect(decoded_response['bulk_token']).to be_nil
        end

        it 'returns a populated bulk_token for the initial request (which has an empty bulk token)' do
          get '/bulk/apps', {
            'batch_size' => 20,
            'bulk_token' => '{}',
          }
          expect(decoded_response['bulk_token']).not_to be_nil
        end

        it 'returns results in the response body' do
          get '/bulk/apps', {
            'batch_size' => 20,
            'bulk_token' => '{"id":20}',
          }
          expect(last_response.status).to eq(200)
          expect(decoded_response['results']).not_to be_nil
        end

        it 'returns results that are valid json' do
          get '/bulk/apps', {
            'batch_size' => 100,
            'bulk_token' => '{"id":0}',
          }
          expect(last_response.status).to eq(200)
          decoded_response['results'].each { |key, value|
            expect(value).to be_kind_of Hash
            expect(value['id']).not_to be_nil
            expect(value['version']).not_to be_nil
          }
        end

        it 'respects the batch_size parameter' do
          [3, 5].each { |size|
            get '/bulk/apps', {
              'batch_size' => size,
              'bulk_token' => '{"id":0}',
            }
            expect(decoded_response['results'].size).to eq(size)
          }
        end

        it 'returns non-intersecting results when token is supplied' do
          get '/bulk/apps', {
            'batch_size' => 2,
            'bulk_token' => '{"id":0}',
          }
          saved_results = decoded_response['results'].dup
          expect(saved_results.size).to eq(2)

          get '/bulk/apps', {
            'batch_size' => 2,
            'bulk_token' => MultiJson.dump(decoded_response['bulk_token']),
          }
          new_results = decoded_response['results'].dup
          expect(new_results.size).to eq(2)
          saved_results.each do |saved_result|
            expect(new_results).not_to include(saved_result)
          end
        end

        it 'should eventually return entire collection, batch after batch' do
          apps = {}
          total_size = App.count

          token = '{}'
          while apps.size < total_size
            get '/bulk/apps', {
              'batch_size' => 2,
              'bulk_token' => MultiJson.dump(token),
            }
            expect(last_response.status).to eq(200)
            token = decoded_response['bulk_token']
            apps.merge!(decoded_response['results'])
          end

          expect(apps.size).to eq(total_size)
          get '/bulk/apps', {
            'batch_size' => 2,
            'bulk_token' => MultiJson.dump(token),
          }
          expect(decoded_response['results'].size).to eq(0)
        end

        it 'does not include diego apps' do
          app = AppFactory.make(state: 'STARTED', package_state: 'STAGED', diego: true)

          get '/bulk/apps', {
                              'batch_size' => 20,
                              'bulk_token' => '{}',
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
