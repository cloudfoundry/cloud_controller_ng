require 'spec_helper'
require 'presenters/helpers/quota_presenter_builder'

module VCAP::CloudController::Presenters
  RSpec.describe QuotaPresenterBuilder do
    let(:quota_struct) do
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
      )
    end
    let(:quota) { quota_struct.new(1024, 512, 10, 5, 1000, true, 50, -1, 100, 10) }

    describe '#add_resource_limits' do
      let(:quota_hash) { QuotaPresenterBuilder.new(quota).add_resource_limits.build }

      it 'builds the quota hash with resource limits' do
        expect(quota_hash).to eq({
                                   apps: {
                                     total_memory_in_mb: 1024,
                                     per_process_memory_in_mb: 512,
                                     total_instances: 10,
                                     per_app_tasks: 5,
                                     log_rate_limit_in_bytes_per_second: 1000
                                   },
                                   services: {
                                     paid_services_allowed: true,
                                     total_service_instances: 50,
                                     total_service_keys: nil
                                   },
                                   routes: {
                                     total_routes: 100,
                                     total_reserved_ports: 10
                                   }
                                 })
      end

      context 'when the quota is an organization quota' do
        let(:quota) { VCAP::CloudController::QuotaDefinition.make(name: 'org-quota') }

        it 'includes guid, created_at, updated_at, and name in the quota hash' do
          expect(quota_hash[:guid]).to eq(quota.guid)
          expect(quota_hash[:created_at]).to eq(quota.created_at)
          expect(quota_hash[:updated_at]).to eq(quota.updated_at)
          expect(quota_hash[:name]).to eq('org-quota')
        end
      end

      context 'when the quota is a space quota' do
        let(:quota) { VCAP::CloudController::SpaceQuotaDefinition.make(name: 'space-quota') }

        it 'includes guid, created_at, updated_at, and name in the quota hash' do
          expect(quota_hash[:guid]).to eq(quota.guid)
          expect(quota_hash[:created_at]).to eq(quota.created_at)
          expect(quota_hash[:updated_at]).to eq(quota.updated_at)
          expect(quota_hash[:name]).to eq('space-quota')
        end
      end
    end

    describe '#add_domains' do
      it 'adds domain limits to the quota hash' do
        builder = QuotaPresenterBuilder.new(VCAP::CloudController::QuotaDefinition.make(name: 'domain-name', total_private_domains: 20))
        builder.add_domains
        quota_hash = builder.build
        expect(quota_hash[:domains]).to eq({ total_domains: 20 })
      end
    end

    describe '#add_relationships' do
      it 'adds relationships to the quota hash' do
        relationships = { organizations: { data: [{ guid: 'org-guid-1' }, { guid: 'org-guid-2' }] } }
        quota_hash = QuotaPresenterBuilder.new(quota).add_relationships(relationships).build
        expect(quota_hash[:relationships]).to eq(relationships)
      end
    end

    describe '#add_links' do
      it 'adds links to the quota hash' do
        links = { self: { href: 'http://example.com/quota' }, 'some-other-link': { href: 'http://example.com/other' } }
        quota_hash = QuotaPresenterBuilder.new(quota).add_links(links).build
        expect(quota_hash[:links]).to eq(links)
      end
    end
  end
end
