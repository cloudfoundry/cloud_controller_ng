require 'spec_helper'
require 'cloud_controller/backends/non_quota_validating_staging_memory_calculator'

module VCAP::CloudController
  RSpec.describe NonQuotaValidatingStagingMemoryCalculator do
    let(:calculator) { NonQuotaValidatingStagingMemoryCalculator.new }

    describe '#get_limit' do
      let(:minimum_limit) { 10 }
      let(:requested_limit) { 100 }

      let(:unused_space) { nil }
      let(:unused_org) { nil }

      before do
        allow(calculator).to receive(:minimum_limit).and_return(minimum_limit)
      end

      it 'uses the requested_limit' do
        limit = calculator.get_limit(requested_limit, unused_space, unused_org)
        expect(limit).to eq(requested_limit)
      end

      context 'when the requested_limit is less than the minimum limit' do
        let(:requested_limit) { minimum_limit - 1 }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit, unused_space, unused_org)
          expect(limit).to eq(minimum_limit)
        end
      end

      context 'when the requested_limit is nil' do
        let(:requested_limit) { nil }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit, unused_space, unused_org)
          expect(limit).to eq(minimum_limit)
        end
      end
    end

    describe '#minimum_limit' do
      context 'when the value is in the configuration' do
        let(:expected_limit) { 99 }
        before do
          TestConfig.override(staging: {
            minimum_staging_memory_mb: expected_limit
          })
        end

        it 'returns the configured value' do
          expect(calculator.minimum_limit).to eq(expected_limit)
        end
      end

      context 'when there is no configured value' do
        before do
          TestConfig.override(staging: {
            minimum_staging_memory_mb: nil
          })
        end

        it 'returns 1024' do
          expect(calculator.minimum_limit).to eq(1024)
        end
      end
    end
  end
end
