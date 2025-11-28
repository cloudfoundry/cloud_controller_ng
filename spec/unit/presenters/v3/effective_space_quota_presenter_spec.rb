require 'spec_helper'
require 'presenters/v3/effective_space_quota_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe EffectiveSpaceQuotaPresenter do
    let(:effective_space_quota) do
      Struct.new(
        :memory_limit,
        :instance_memory_limit,
        :app_instance_limit,
        :app_task_limit,
        :log_rate_limit,
        :non_basic_services_allowed,
        :total_services,
        :total_service_keys,
        :total_routes,
        :total_reserved_route_ports
      ).new(2048, 1024, 20, 10, 1500, true, 100, 5, 200, 15)
    end
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid') }

    describe '#to_hash' do
      let(:result) { EffectiveSpaceQuotaPresenter.new(effective_space_quota, space).to_hash }

      it 'presents the effective space quota as json' do
        expect(result[:apps][:total_memory_in_mb]).to eq(effective_space_quota.memory_limit)
        expect(result[:apps][:per_process_memory_in_mb]).to eq(effective_space_quota.instance_memory_limit)
        expect(result[:apps][:total_instances]).to eq(effective_space_quota.app_instance_limit)
        expect(result[:apps][:per_app_tasks]).to eq(effective_space_quota.app_task_limit)
        expect(result[:apps][:log_rate_limit_in_bytes_per_second]).to eq(effective_space_quota.log_rate_limit)
        expect(result[:services][:paid_services_allowed]).to eq(effective_space_quota.non_basic_services_allowed)
        expect(result[:services][:total_service_instances]).to eq(effective_space_quota.total_services)
        expect(result[:services][:total_service_keys]).to eq(effective_space_quota.total_service_keys)
        expect(result[:routes][:total_routes]).to eq(effective_space_quota.total_routes)
        expect(result[:routes][:total_reserved_ports]).to eq(effective_space_quota.total_reserved_route_ports)
        expect(result[:links][:self][:href]).to match(%r{/v3/spaces/#{space.guid}/effective_quota$})
        expect(result[:links][:usage_summary][:href]).to match(%r{/v3/spaces/#{space.guid}/usage_summary$})
        expect(result[:links][:space][:href]).to match(%r{/v3/spaces/#{space.guid}$})
      end

      it 'calls the QuotaPresenterBuilder' do
        allow(VCAP::CloudController::Presenters::QuotaPresenterBuilder).to receive(:new).and_call_original
        result
        expect(VCAP::CloudController::Presenters::QuotaPresenterBuilder).to have_received(:new).with(effective_space_quota)
      end
    end
  end
end
