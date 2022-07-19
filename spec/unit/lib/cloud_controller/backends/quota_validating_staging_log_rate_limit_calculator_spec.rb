require 'spec_helper'
require 'cloud_controller/backends/quota_validating_staging_log_rate_limit_calculator'

module VCAP::CloudController
  RSpec.describe QuotaValidatingStagingLogRateLimitCalculator do
    let(:calculator) { QuotaValidatingStagingLogRateLimitCalculator.new }

    describe '#get_limit' do
      let(:space_quota_limit) { 200 }
      let(:org_quota_limit) { 200 }
      let(:requested_limit) { 100 }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:space_quota_definition) { SpaceQuotaDefinition.make(organization: org, log_rate_limit: space_quota_limit) }
      let(:quota_definition) { QuotaDefinition.make(log_rate_limit: org_quota_limit) }

      before do
        space.space_quota_definition = space_quota_definition
        org.quota_definition = quota_definition
        space.save
        org.save
      end

      it 'uses the requested_limit' do
        limit = calculator.get_limit(requested_limit, space, org)
        expect(limit).to eq(requested_limit)
      end

      context 'when the requested_limit is passed as an integer string' do
        let(:requested_limit) { '100' }

        it 'uses the requested_limit' do
          limit = calculator.get_limit(requested_limit, space, org)
          expect(limit).to eq(100)
        end
      end

      context 'when the requested_limit exceeds the space quota' do
        let(:space_quota_limit) { requested_limit - 1 }

        it 'raises a SpaceQuotaExceeded error' do
          expect {
            calculator.get_limit(requested_limit, space, org)
          }.to raise_error(QuotaValidatingStagingLogRateLimitCalculator::SpaceQuotaExceeded, /staging requires 100 bytes per second/)
        end
      end

      context 'when the requested_limit exceeds the org quota' do
        let(:org_quota_limit) { requested_limit - 1 }

        it 'raises a OrgQuotaExceeded error' do
          expect {
            calculator.get_limit(requested_limit, space, org)
          }.to raise_error(QuotaValidatingStagingLogRateLimitCalculator::OrgQuotaExceeded, /staging requires 100 bytes per second/)
        end
      end

      context 'when the requested_limit is nil' do
        let(:requested_limit) { nil }

        it 'uses no limit' do
          limit = calculator.get_limit(requested_limit, space, org)
          expect(limit).to eq(-1)
        end
      end
    end
  end
end
