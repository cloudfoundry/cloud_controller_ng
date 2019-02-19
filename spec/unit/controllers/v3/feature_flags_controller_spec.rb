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
end
