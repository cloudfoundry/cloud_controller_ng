require 'rails_helper'

RSpec.describe FeatureFlagsController, type: :controller do
  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let(:flag_defaults) { VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS }
    let(:flag_names_sorted) { flag_defaults.keys.sort.map(&:to_s) }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'reader' => 200,
        'unauthenticated' => 401,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, user: user)

            get :index

            expect(response.status).to eq expected_return_value
          end
        end
      end
    end

    context 'when the user is logged in' do
      let(:feature_flag_key) { :user_org_creation }
      let(:feature_flag_default) { flag_defaults[feature_flag_key] }

      before do
        set_current_user(user)
      end

      context 'when there are no overrides' do
        it 'returns the flags with their default values' do
          get :index

          actual_feature_flag = parsed_body['resources'].find { |feature_flag| feature_flag['name'] == feature_flag_key.to_s }
          expect(actual_feature_flag).to_not be_nil
          expect(actual_feature_flag['enabled']).to eq(feature_flag_default)
          expect(actual_feature_flag['updated_at']).to be_nil
          expect(actual_feature_flag['error_message']).to be_nil
        end
      end

      context 'when there are overrides from the database' do
        let!(:updated_feature_flag) do
          VCAP::CloudController::FeatureFlag.make(name: feature_flag_key, enabled: true, error_message: 'some_custom_message')
        end

        it 'returns the flags with their overridden for enabled where needed' do
          get :index
          actual_feature_flag = parsed_body['resources'].find { |feature_flag| feature_flag['name'] == feature_flag_key.to_s }
          expect(actual_feature_flag).to_not be_nil
          expect(actual_feature_flag['enabled']).to be_truthy
          expect(actual_feature_flag['updated_at']).to eq(updated_feature_flag.updated_at.utc.iso8601)
          expect(actual_feature_flag['custom_error_message']).to eq('some_custom_message')
        end
      end

      describe 'pagination' do
        let(:feature_flag_names_sorted) {}
        it 'supports pagination' do
          get :index, params: { per_page: 1, page: 2 }

          expect(parsed_body['resources'].length).to eq 1
          expect(parsed_body['pagination']['total_results']).to eq(flag_defaults.size)
        end

        it 'sorts the feature flags by name' do
          get :index

          response_names = parsed_body['resources'].collect { |ff| ff['name'] }
          expect(response_names).to eq(flag_names_sorted)
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
        flag1: false,
      })
      set_current_user(user)
    end

    context 'when there are no overrides' do
      it 'returns the flag with the default value' do
        get :show, params: { name: 'flag1' }

        expect(response.status).to eq(200)
        expect(parsed_body['name']).to eq('flag1')
        expect(parsed_body['enabled']).to eq(false)
      end
    end

    context 'when there are overrides' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'flag1', enabled: true, error_message: nil) }

      it 'returns the overridden value' do
        get :show, params: { name: 'flag1' }

        expect(response.status).to eq(200)

        expect(parsed_body['name']).to eq('flag1')
        expect(parsed_body['enabled']).to eq(true)
      end
    end

    context 'when the flag does not exist' do
      it 'returns 404' do
        get :show, params: { name: 'flag90' }

        expect(response.status).to eq(404)
      end
    end
  end

  describe '#update' do
    let(:user) { VCAP::CloudController::User.make }
    let(:feature_flag_name) { 'flag1' }

    before do
      stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
        flag1: false,
      })
      set_current_user(user)
    end

    context 'when user is not an admin' do
      before do
        set_current_user_as_reader_and_writer(user: user)
      end

      it 'returns 403' do
        patch :update, params: { name: feature_flag_name }

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when user is an admin' do
      before do
        set_current_user_as_admin(user: user)
      end

      context 'when updating the feature flag fails' do
        before do
          mock_ff_update = instance_double(VCAP::CloudController::FeatureFlagUpdate)
          allow(mock_ff_update).to receive(:update).and_raise(VCAP::CloudController::FeatureFlagUpdate::Error.new('that did not work'))
          allow(VCAP::CloudController::FeatureFlagUpdate).to receive(:new).and_return(mock_ff_update)
        end

        it 'returns a 422 with the error message' do
          patch :update, params: { name: feature_flag_name, enabled: true }, as: :json

          expect(response.status).to eq 422
          expect(parsed_body['errors'].first['detail']).to eq 'that did not work'
        end
      end

      context 'when the request is not valid' do
        it 'returns an unprocessable error message' do
          patch :update, params: {
            name: feature_flag_name,
            bogus_param: 'bogus value'
          }
          expect(response.status).to eq 422
          expect(response.body).to include 'Unknown field'
        end
      end
      context 'when the flag does not exist' do
        it 'returns 404' do
          patch :update, params: {
            name: 'flag2',
            enabled: true
          }
          expect(response.status).to eq(404)
        end
      end
      context 'when the request is valid' do
        it 'returns updated feature flag' do
          patch :update, params: {
            name: feature_flag_name,
            enabled: false,
            custom_error_message: 'Here is my custom error message!'
          }, as: :json

          expect(response.status).to eq 200
          expect(parsed_body['enabled']).to eq false
          expect(parsed_body['custom_error_message']).to eq 'Here is my custom error message!'
        end

        it 'works with an empty request body' do
          patch :update, params: {
            name: feature_flag_name,
          }, as: :json

          expect(response.status).to eq 200
          expect(parsed_body['enabled']).to eq false
          expect(parsed_body['custom_error_message']).to be_nil
        end

        it 'allows blanking of the error message' do
          patch :update, params: {
            name: feature_flag_name,
            custom_error_message: 'something'
          }, as: :json

          expect(response.status).to eq 200
          expect(parsed_body['custom_error_message']).to eq 'something'

          patch :update, params: {
            name: feature_flag_name,
            custom_error_message: nil
          }, as: :json

          expect(response.status).to eq 200
          expect(parsed_body['custom_error_message']).to be_nil
        end
      end
    end
  end
end
