require 'spec_helper'

module VCAP::CloudController
  describe FeatureFlagsController, type: :controller do
    describe 'PUT /v2/config/feature_flags/:name' do
      context 'when the user is an admin' do
        context 'and the flag is in the default feature flags' do
          context 'and the flag was NOT previously set' do
            it 'sets the feature flag to the specified value' do
              put '/v2/config/feature_flags/user_org_creation', MultiJson.dump({ enabled: true, error_message: 'foobar' }), admin_headers

              expect(last_response.status).to eq(200)
              expect(decoded_response['name']).to eq('user_org_creation')
              expect(decoded_response['enabled']).to be true
              expect(decoded_response['error_message']).to eq('foobar')
              expect(decoded_response['url']).to eq('/v2/config/feature_flags/user_org_creation')
            end
          end

          context 'and the flag was previously set' do
            before { FeatureFlag.make(name: 'user_org_creation', enabled: false, error_message: 'foobar') }

            it 'sets the feature flag to the specified value' do
              put '/v2/config/feature_flags/user_org_creation', MultiJson.dump({ enabled: true, error_message: 'baz' }), admin_headers

              expect(last_response.status).to eq(200)
              expect(decoded_response['name']).to eq('user_org_creation')
              expect(decoded_response['enabled']).to be true
              expect(decoded_response['error_message']).to eq('baz')
              expect(decoded_response['url']).to eq('/v2/config/feature_flags/user_org_creation')
            end
          end
        end

        context 'and the flag is not a default feature flag' do
          it 'returns a 404' do
            put '/v2/config/feature_flags/bogus', {}, admin_headers

            expect(last_response.status).to eq(404)
            expect(decoded_response['description']).to match(/feature flag could not be found/)
            expect(decoded_response['error_code']).to match(/FeatureFlagNotFound/)
          end
        end

        context 'and the feature flag is invalid' do
          it 'responds to user with FeatureFlagInvalid' do
            put '/v2/config/feature_flags/user_org_creation', MultiJson.dump({ enabled: nil }), admin_headers

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match(/feature flag is invalid/)
            expect(decoded_response['error_code']).to match(/FeatureFlagInvalid/)
          end
        end
      end

      context 'when the user is not an admin' do
        it 'returns a 403' do
          put '/v2/config/feature_flags/user_org_creation', MultiJson.dump({ enabled: true }), headers_for(User.make)

          expect(last_response.status).to eq(403)
          expect(decoded_response['description']).to match(/not authorized/)
          expect(decoded_response['error_code']).to match(/NotAuthorized/)
        end
      end
    end

    describe 'GET /v2/config/feature_flags' do
      before do
        stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
          flag1: false,
          flag2: true,
          flag3: false,
        })
      end

      context 'when there are no overrides' do
        it 'returns all the flags with their default values' do
          get '/v2/config/feature_flags', '{}', admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response.length).to eq(3)
          expect(decoded_response).to include(
            {
              'name'          => 'flag1',
              'enabled'       => false,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag1'
            })
          expect(decoded_response).to include(
            {
              'name'          => 'flag2',
              'enabled'       => true,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag2'
            })
          expect(decoded_response).to include(
            {
              'name'          => 'flag3',
              'enabled'       => false,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag3'
            })
        end
      end

      context 'when there are overrides' do
        before { FeatureFlag.make(name: 'flag1', enabled: true, error_message: 'custom_error_message') }

        it 'returns the defaults, overridden where needed' do
          get '/v2/config/feature_flags', '{}', admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response.length).to eq(3)
          expect(decoded_response).to include(
            {
              'name'          => 'flag1',
              'enabled'       => true,
              'error_message' => 'custom_error_message',
              'url'           => '/v2/config/feature_flags/flag1'
            })
          expect(decoded_response).to include(
            {
              'name'          => 'flag2',
              'enabled'       => true,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag2'
            })
          expect(decoded_response).to include(
            {
              'name'          => 'flag3',
              'enabled'       => false,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag3'
            })
        end
      end
    end

    describe 'GET /v2/config/feature_flags/:name' do
      before do
        stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
          flag1: false,
        })
      end

      context 'when there are no overrides' do
        it 'returns the flag with the default value' do
          get '/v2/config/feature_flags/flag1', '{}', admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response).to eq(
            {
              'name'          => 'flag1',
              'enabled'       => false,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag1'
            })
        end
      end

      context 'when there are overrides' do
        before { FeatureFlag.make(name: 'flag1', enabled: true, error_message: nil) }

        it 'returns the overridden value' do
          get '/v2/config/feature_flags/flag1', '{}', admin_headers

          expect(last_response.status).to eq(200)
          expect(decoded_response).to eq(
            {
              'name'          => 'flag1',
              'enabled'       => true,
              'error_message' => nil,
              'url'           => '/v2/config/feature_flags/flag1'
            })
        end
      end

      context 'when the flag does not exist' do
        it 'returns 404' do
          get '/v2/config/feature_flags/bogus-flag', '{}', admin_headers

          expect(last_response.status).to eq(404)
          expect(decoded_response['description']).to match(/feature flag could not be found/)
          expect(decoded_response['error_code']).to match(/FeatureFlagNotFound/)
        end
      end
    end
  end
end
