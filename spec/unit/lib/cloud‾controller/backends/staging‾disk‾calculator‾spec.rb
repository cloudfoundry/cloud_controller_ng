require 'spec_helper'
require 'cloud_controller/backends/staging_disk_calculator'

module VCAP::CloudController
  RSpec.describe StagingDiskCalculator do
    let(:calculator) { StagingDiskCalculator.new }

    describe '#get_limit' do
      let(:minimum_limit) { 10 }
      let(:maximum_limit) { 200 }
      let(:requested_limit) { 100 }

      before do
        allow(calculator).to receive(:minimum_limit).and_return(minimum_limit)
        allow(calculator).to receive(:maximum_limit).and_return(maximum_limit)
      end

      it 'uses the requested_limit' do
        limit = calculator.get_limit(requested_limit)
        expect(limit).to eq(requested_limit)
      end

      context 'when the requested_limit is less than the minimum limit' do
        let(:requested_limit) { minimum_limit - 1 }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit)
          expect(limit).to eq(minimum_limit)
        end
      end

      context 'when the requested_limit is less than the minimum limit' do
        let(:requested_limit) { '100' }

        it 'uses the requested_limit' do
          limit = calculator.get_limit(requested_limit)
          expect(limit).to eq(100)
        end
      end

      context 'when the requested_limit is greater than the maximum limit' do
        let(:requested_limit) { maximum_limit + 1 }

        it 'raises StagingDiskCalculator::LimitExceeded' do
          expect {
            calculator.get_limit(requested_limit)
          }.to raise_error(StagingDiskCalculator::LimitExceeded)
        end
      end

      context 'when the requested_limit is nil' do
        let(:requested_limit) { nil }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit)
          expect(limit).to eq(minimum_limit)
        end
      end
    end

    describe '#minimum_limit' do
      context 'when the value is in the configuration' do
        let(:expected_limit) { 99 }
        before do
          TestConfig.override(staging: { minimum_staging_disk_mb: expected_limit })
        end

        it 'returns the configured value' do
          expect(calculator.minimum_limit).to eq(expected_limit)
        end
      end
    end

    describe '#maximum_limit' do
      let(:minimum_limit) { 10 }
      let(:maximum_limit) { minimum_limit + 1 }

      before do
        allow(calculator).to receive(:minimum_limit).and_return(minimum_limit)
        TestConfig.override(maximum_app_disk_in_mb: maximum_limit)
      end

      it 'returns the configured value' do
        expect(calculator.maximum_limit).to eq(maximum_limit)
      end

      context 'when the configured running value is less than the staging minimum_limit' do
        let(:maximum_limit) { minimum_limit - 1 }

        it 'returns the minimum_limit' do
          expect(calculator.maximum_limit).to eq(minimum_limit)
        end
      end

      context 'when there is no configured value' do
        let(:maximum_limit) { nil }

        it 'returns the minimum_limit' do
          expect(calculator.maximum_limit).to eq(minimum_limit)
        end
      end
    end
  end
end
