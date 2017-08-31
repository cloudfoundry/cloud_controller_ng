require 'spec_helper'
require 'cloud_controller/backends/quota_validating_staging_memory_calculator'

module VCAP::CloudController
  RSpec.describe QuotaValidatingStagingMemoryCalculator do
    let(:calculator) { QuotaValidatingStagingMemoryCalculator.new }

    describe '#get_limit' do
      let(:minimum_limit) { 10 }
      let(:space_quota_limit) { 200 }
      let(:org_quota_limit) { 200 }
      let(:requested_limit) { 100 }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:space_quota_definition) { SpaceQuotaDefinition.make(organization: org, memory_limit: space_quota_limit) }
      let(:quota_definition) { QuotaDefinition.make(memory_limit: org_quota_limit) }

      before do
        allow(calculator).to receive(:minimum_limit).and_return(minimum_limit)
        space.space_quota_definition = space_quota_definition
        org.quota_definition = quota_definition
        space.save
        org.save
      end

      it 'uses the requested_limit' do
        limit = calculator.get_limit(requested_limit, space, org)
        expect(limit).to eq(requested_limit)
      end

      context 'when the requested_limit is less than the minimum limit' do
        let(:requested_limit) { minimum_limit - 1 }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit, space, org)
          expect(limit).to eq(minimum_limit)
        end
      end

      context 'when the requested_limit is passed as an integer string' do
        let(:requested_limit) { '100' }

        it 'uses the requested_limit' do
          limit = calculator.get_limit(requested_limit, space, org)
          expect(limit).to eq(100)
        end
      end

      context 'when the requested_limit is greater than the minimum limit' do
        context 'when the requested_limit exceeds the space quota' do
          let(:space_quota_limit) { requested_limit - 1 }

          it 'raises MemoryLimitCalculator::SpaceQuotaExceeded' do
            expect {
              calculator.get_limit(requested_limit, space, org)
            }.to raise_error(QuotaValidatingStagingMemoryCalculator::SpaceQuotaExceeded, /staging requires 100M memory/)
          end
        end

        context 'when the requested_limit exceeds the org quota' do
          let(:org_quota_limit) { requested_limit - 1 }

          it 'raises MemoryLimitCalculator::OrgQuotaExceeded' do
            expect {
              calculator.get_limit(requested_limit, space, org)
            }.to raise_error(QuotaValidatingStagingMemoryCalculator::OrgQuotaExceeded, /staging requires 100M memory/)
          end
        end
      end

      context 'when the requested_limit is nil' do
        let(:requested_limit) { nil }

        it 'uses the minimum limit' do
          limit = calculator.get_limit(requested_limit, space, org)
          expect(limit).to eq(minimum_limit)
        end
      end
    end

    describe '#minimum_limit' do
      context 'when the value is in the configuration' do
        let(:expected_limit) { 99 }
        before do
          TestConfig.override(staging: { minimum_staging_memory_mb: expected_limit })
        end

        it 'returns the configured value' do
          expect(calculator.minimum_limit).to eq(expected_limit)
        end
      end

      context 'when there is no configured value' do
        before do
          TestConfig.override(staging: { minimum_staging_memory_mb: nil })
        end

        it 'returns 1024' do
          expect(calculator.minimum_limit).to eq(1024)
        end
      end
    end
  end
end
