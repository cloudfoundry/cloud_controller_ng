require 'spec_helper'
require 'fetchers/organization_quota_summary_fetcher'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaSummaryFetcher do
    subject { OrganizationQuotaSummaryFetcher.new(org) }

    let(:org) { Organization.make }
    let(:quota) do
      VCAP::CloudController::QuotaDefinition.make(
        memory_limit: 1024,
        instance_memory_limit: 128,
        app_instance_limit: 10,
        app_task_limit: 4,
        total_services: 10,
        total_service_keys: 10,
        total_routes: 10,
        total_reserved_route_ports: 5,
        log_rate_limit: 1000
      )
    end

    before do
      org.quota_definition = quota
      org.save
    end

    describe '#fetch' do
      it 'returns the organization quota limits' do
        summary = subject.fetch
        expect(summary[:apps][:total_memory_in_mb][:limit]).to eq(1024)
        expect(summary[:apps][:total_instances][:limit]).to eq(10)
        expect(summary[:services][:total_service_instances][:limit]).to eq(10)
        expect(summary[:services][:total_service_keys][:limit]).to eq(10)
      end

      context 'when the organization has unlimited quotas' do
        before do
          quota.update(
            memory_limit: -1,
            instance_memory_limit: -1,
            app_instance_limit: -1,
            app_task_limit: -1,
            total_services: -1,
            total_service_keys: -1,
            total_routes: -1,
            total_reserved_route_ports: -1,
            log_rate_limit: -1
          )
        end

        it 'returns -1 for unlimited values' do
          summary = subject.fetch
          expect(summary[:apps][:total_memory_in_mb][:limit]).to eq(-1)
          expect(summary[:apps][:total_instances][:limit]).to eq(-1)
          expect(summary[:services][:total_service_instances][:limit]).to eq(-1)
          expect(summary[:services][:total_service_keys][:limit]).to eq(-1)
        end
      end
    end
  end
end

