require 'rails_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe FeatureFlagsController, type: :controller do
  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let(:flag_defaults) { VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS }
    let(:flag_names_sorted) { flag_defaults.keys.sort.map(&:to_s) }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'reader' => 200,
        'unauthenticated' => 401
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role:, user:)

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
          expect(actual_feature_flag).not_to be_nil
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
          expect(actual_feature_flag).not_to be_nil
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

          response_names = parsed_body['resources'].pluck('name')
          expect(response_names).to eq(flag_names_sorted)
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
                   flag1: false
                 })
      set_current_user(user)
    end

    context 'when there are no overrides' do
      it 'returns the flag with the default value' do
        get :show, params: { name: 'flag1' }

        expect(response).to have_http_status(:ok)
        expect(parsed_body['name']).to eq('flag1')
        expect(parsed_body['enabled']).to be(false)
      end
    end

    context 'when there are overrides' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'flag1', enabled: true, error_message: nil) }

      it 'returns the overridden value' do
        get :show, params: { name: 'flag1' }

        expect(response).to have_http_status(:ok)

        expect(parsed_body['name']).to eq('flag1')
        expect(parsed_body['enabled']).to be(true)
      end
    end

    context 'when the flag does not exist' do
      it 'returns 404' do
        get :show, params: { name: 'flag90' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    let(:user) { VCAP::CloudController::User.make }
    let(:feature_flag_name) { 'flag1' }

    before do
      stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
                   flag1: false
                 })
      set_current_user(user)
    end

    context 'when user is not an admin' do
      before do
        set_current_user_as_reader_and_writer(user:)
      end

      it 'returns 403' do
        patch :update, params: { name: feature_flag_name }

        expect(response).to have_http_status :forbidden
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when user is an admin' do
      before do
        set_current_user_as_admin(user:)
      end

      context 'when updating the feature flag fails' do
        before do
          mock_ff_update = instance_double(VCAP::CloudController::FeatureFlagUpdate)
          allow(mock_ff_update).to receive(:update).and_raise(VCAP::CloudController::FeatureFlagUpdate::Error.new('that did not work'))
          allow(VCAP::CloudController::FeatureFlagUpdate).to receive(:new).and_return(mock_ff_update)
        end

        it 'returns a 422 with the error message' do
          patch :update, params: { name: feature_flag_name, enabled: true }, as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(parsed_body['errors'].first['detail']).to eq 'that did not work'
        end
      end

      context 'when the request is not valid' do
        it 'returns an unprocessable error message' do
          patch :update, params: {
            name: feature_flag_name,
            bogus_param: 'bogus value'
          }
          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'Unknown field'
        end
      end

      context 'when the flag does not exist' do
        it 'returns 404' do
          patch :update, params: {
            name: 'flag2',
            enabled: true
          }
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when the request is valid' do
        it 'returns updated feature flag' do
          patch :update, params: {
            name: feature_flag_name,
            enabled: false,
            custom_error_message: 'Here is my custom error message!'
          }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['enabled']).to be false
          expect(parsed_body['custom_error_message']).to eq 'Here is my custom error message!'
        end

        it 'works with an empty request body' do
          patch :update, params: {
            name: feature_flag_name
          }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['enabled']).to be false
          expect(parsed_body['custom_error_message']).to be_nil
        end

        it 'allows blanking of the error message' do
          patch :update, params: {
            name: feature_flag_name,
            custom_error_message: 'something'
          }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['custom_error_message']).to eq 'something'

          patch :update, params: {
            name: feature_flag_name,
            custom_error_message: nil
          }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['custom_error_message']).to be_nil
        end
      end

      context 'when there are overrides in configuration' do
        before do
          stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', {
                       flag1: false, flag2: true, flag3: true, flag4: false
                     })
          VCAP::CloudController::FeatureFlag.override_default_flags({ flag1: false, flag4: true })
        end

        it 'returns a warning message for the overridden flags' do
          patch :update, params: {
            name: 'flag1',
            enabled: false
          }, as: :json

          expect(response).to have_http_status :ok
          expect(response).to have_warning_message FeatureFlagsController::OVERRIDE_IN_MANIFEST_MSG

          patch :update, params: {
            name: 'flag4',
            enabled: false
          }, as: :json

          expect(response).to have_http_status :ok
          expect(response).to have_warning_message FeatureFlagsController::OVERRIDE_IN_MANIFEST_MSG
        end

        it 'returns no warning message for not overridden flags' do
          patch :update, params: {
            name: 'flag2',
            enabled: false
          }, as: :json

          expect(response).to have_http_status :ok
          expect(response.headers['X-Cf-Warnings']).to be_nil

          patch :update, params: {
            name: 'flag3',
            enabled: false
          }, as: :json

          expect(response).to have_http_status :ok
          expect(response.headers['X-Cf-Warnings']).to be_nil
        end
      end
    end
  end
end
