require 'spec_helper'
require 'presenters/v3/feature_flag_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe FeatureFlagPresenter do
    let(:feature_flag) { VCAP::CloudController::FeatureFlag.make }

    describe '#to_hash' do
      let(:result) { FeatureFlagPresenter.new(feature_flag).to_hash }

      describe 'links' do
        it 'has self link' do
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/feature_flags/#{feature_flag.name}")
        end
      end

      it 'presents the feature flag with those fields' do
        expect(result[:name]).to eq(feature_flag.name)
        expect(result[:enabled]).to eq(feature_flag.enabled)
        expect(result[:updated_at]).to eq(feature_flag.updated_at)
        expect(result[:custom_error_message]).to eq(feature_flag.error_message)
      end

      context 'when the feature flag is unsaved' do
        let(:feature_flag) { VCAP::CloudController::FeatureFlag.new(name: 'feature_flag', enabled: true) }

        it 'presents the feature flag with updated_at and custom error message as nil' do
          expect(result[:name]).to eq('feature_flag')
          expect(result[:enabled]).to eq(true)
          expect(result[:updated_at]).to be_nil
          expect(result[:custom_error_message]).to be_nil
        end
      end
    end
  end
end
