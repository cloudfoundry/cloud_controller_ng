require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FeatureFlag, type: :model do
    describe 'diego_custom_stacks feature flag' do
      context 'when the diego_custom_stacks feature flag is not overridden' do
        it 'returns the default value (disabled)' do
          expect(FeatureFlag.enabled?(:diego_custom_stacks)).to be(false)
          expect(FeatureFlag.disabled?(:diego_custom_stacks)).to be(true)
        end
      end

      context 'when the diego_custom_stacks feature flag is enabled' do
        before do
          FeatureFlag.make(name: 'diego_custom_stacks', enabled: true)
        end

        it 'returns true' do
          expect(FeatureFlag.enabled?(:diego_custom_stacks)).to be(true)
        end
      end

      context 'when the diego_custom_stacks feature flag is disabled' do
        before do
          FeatureFlag.make(name: 'diego_custom_stacks', enabled: false)
        end

        it 'raises FeatureDisabled when raise_unless_enabled!' do
          expect {
            FeatureFlag.raise_unless_enabled!(:diego_custom_stacks)
          }.to raise_error(CloudController::Errors::ApiError) { |error|
            expect(error.name).to eq('FeatureDisabled')
          }
        end
      end
    end
  end
end
