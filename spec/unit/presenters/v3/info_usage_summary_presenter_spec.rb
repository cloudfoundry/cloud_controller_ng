require 'spec_helper'
require 'presenters/v3/info_usage_summary_presenter'
require 'fetchers/global_usage_summary_fetcher'

module VCAP::CloudController::Presenters::V3
  RSpec.describe InfoUsageSummaryPresenter do
    describe '#to_hash' do
      let(:result) { InfoUsageSummaryPresenter.new(VCAP::CloudController::GlobalUsageSummaryFetcher.summary).to_hash }

      it 'presents the global usage summary as json' do
        expect(result[:usage_summary][:started_instances]).to eq(0)
        expect(result[:usage_summary][:memory_in_mb]).to eq(0)
        expect(result[:usage_summary][:routes]).to eq(0)
        expect(result[:usage_summary][:service_instances]).to eq(0)
        expect(result[:usage_summary][:reserved_ports]).to eq(0)
        expect(result[:usage_summary][:domains]).to eq(1)
        expect(result[:usage_summary][:per_app_tasks]).to eq(0)
        expect(result[:usage_summary][:service_keys]).to eq(0)

        expect(result[:links][:self][:href]).to match(%r{/v3/info/usage_summary$})
      end
    end
  end
end
