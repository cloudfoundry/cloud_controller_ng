require 'spec_helper'
require 'actions/feature_flag_update'
require 'messages/feature_flags_update_message'

module VCAP::CloudController
  RSpec.describe FeatureFlagUpdate do
    describe 'update' do
      context 'when enabled is changed' do
        let(:feature_flag1) { FeatureFlag.make(enabled: true) }

        it 'updates the feature flag enabled field' do
          message = FeatureFlagsUpdateMessage.new(
            enabled: false,
          )
          FeatureFlagUpdate.new.update(feature_flag1, message)

          expect(feature_flag1.enabled).to eq(false)
        end
      end

      context 'when error message is changed' do
        let(:feature_flag1) { FeatureFlag.make(enabled: true, error_message: 'Old error message') }
        it 'updates the  feature flag error message field' do
          message = FeatureFlagsUpdateMessage.new(
            custom_error_message: 'New error message',
            enabled: true
          )
          FeatureFlagUpdate.new.update(feature_flag1, message)

          expect(feature_flag1.error_message).to eq('New error message')
          expect(feature_flag1.enabled).to eq(true)
        end
      end
    end
  end
end
