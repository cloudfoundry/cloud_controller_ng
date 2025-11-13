require 'spec_helper'
require 'fetchers/space_quota_summary_fetcher'

module VCAP::CloudController
  RSpec.describe SpaceQuotaSummaryFetcher do
    subject { SpaceQuotaSummaryFetcher.new(space) }

    before do
      space_quota.add_space(space)
      org_quota.add_organization(org)

      router_group = double('router_group', type: 'tcp', reservable_ports: [8080])
      routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
      allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client:))
    end

    let!(:space) { Space.make }
    let!(:org) { space.organization }

    let!(:org_quota) do
      VCAP::CloudController::QuotaDefinition.make(
        memory_limit: 1024,
        instance_memory_limit: 128,
        app_instance_limit: 10,
        app_task_limit: 4,
        total_services: 10,
        total_service_keys: 10,
        total_routes: 10,
        total_reserved_route_ports: 5,
      )
    end
    let!(:space_quota) do
      VCAP::CloudController::SpaceQuotaDefinition.make(
        organization: org,
        memory_limit: 512,
        instance_memory_limit: 128,
        app_instance_limit: 5,
        app_task_limit: 2,
        total_services: 5,
        total_service_keys: 5,
        total_routes: 5,
        total_reserved_route_ports: 2,
      )
    end

    let!(:app) { AppModel.make(space:) }
    let!(:completed_task) { TaskModel.make(app: app, state: TaskModel::SUCCEEDED_STATE, memory_in_mb: 100) }
    let!(:running_task) { TaskModel.make(app: app, state: TaskModel::RUNNING_STATE, memory_in_mb: 100) }
    let!(:started_process1) { ProcessModelFactory.make(app: app, instances: 3, state: 'STARTED', memory: 100) }
    let!(:stopped_process) { ProcessModelFactory.make(app: app, instances: 2, state: 'STOPPED', memory: 100, type: 'other') }
    let!(:service_instance1) { ServiceInstance.make(is_gateway_service: false, space: space) }
    let!(:service_instance2) { ServiceInstance.make(is_gateway_service: true, space: space) }
    let!(:service_instance3) { ServiceInstance.make(is_gateway_service: true, space: space) }
    let!(:service_key1) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance1) }
    let!(:service_key2) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance2) }
    let!(:shared_domain_with_router_group) { SharedDomain.make(router_group_guid: 'rg-123') }
    let!(:shared_domain_without_router_group) { SharedDomain.make(router_group_guid: nil) }
    let!(:private_domain_without_router_group) { PrivateDomain.make(owning_organization: org) }
    let!(:route1) { Route.make(host: '', domain: shared_domain_with_router_group, port: 8080, space: space) }
    # let!(:route2) { Route.make(host: '', domain: private_domain_without_router_group) }

    describe '#fetch' do
      context 'when space has a lower quota than the organization' do
        it 'uses the space quota limits' do
          summary = subject.fetch
          expect(summary).to eq({
                                  apps: {
                                    total_memory_in_mb: { limit: 512, used: 400, available: 112 },
                                    total_instances: { limit: 5, used: 3, available: 2 }
                                  },
                                  services: {
                                    total_service_instances: { limit: 5, used: 3, available: 2 },
                                    total_service_keys: { limit: 5, used: 2, available: 3 }
                                  },
                                  routes: {
                                    total_routes: { limit: 5, used: 1, available: 4 },
                                    total_reserved_ports: { limit: 2, used: 1, available: 1 }
                                  }
                                })
        end
      end

      context 'when organization has a lower quota than the space' do
        before do
          space_quota.update(
            memory_limit: 2048,
            instance_memory_limit: 256,
            app_instance_limit: 20,
            app_task_limit: 8,
            total_services: 20,
            total_service_keys: 20,
            total_routes: 20,
            total_reserved_route_ports: 5,
            log_rate_limit: 2000
          )
        end

        it 'uses the organization quota limits' do
          summary = subject.fetch
          expect(summary[:memory_limit]).to eq(1024)
          expect(summary[:instance_memory_limit]).to eq(128)
          expect(summary[:app_instance_limit]).to eq(10)
          expect(summary[:app_tasks_limit]).to eq(4)
          expect(summary[:service_instances_limit]).to eq(10)
          expect(summary[:service_keys_limit]).to eq(10)
          expect(summary[:routes_limit]).to eq(10)
          expect(summary[:reserved_route_ports_limit]).to eq(5)
          expect(summary[:log_rate_limit]).to eq(1000)
        end
      end

      context 'when organization has a quota but the space has none' do
        before do
          space.space_quota_definition = nil
          space.save
        end

        it 'uses the organization quota limits' do
          summary = subject.fetch
          expect(summary[:memory_limit]).to eq(1024)
          expect(summary[:instance_memory_limit]).to eq(128)
          expect(summary[:app_instance_limit]).to eq(10)
          expect(summary[:app_tasks_limit]).to eq(4)
          expect(summary[:service_instances_limit]).to eq(10)
          expect(summary[:service_keys_limit]).to eq(10)
          expect(summary[:routes_limit]).to eq(10)
          expect(summary[:reserved_route_ports_limit]).to eq(5)
          expect(summary[:log_rate_limit]).to eq(1000)
        end
      end

      context 'when space has a quota but the organization has unlimited quotas' do
        before do
          org_quota.update(
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

        it 'uses the space quota limits' do
          summary = subject.fetch
          expect(summary[:memory_limit]).to eq(512)
          expect(summary[:instance_memory_limit]).to eq(64)
          expect(summary[:app_instance_limit]).to eq(5)
          expect(summary[:app_tasks_limit]).to eq(2)
          expect(summary[:service_instances_limit]).to eq(5)
          expect(summary[:service_keys_limit]).to eq(5)
          expect(summary[:routes_limit]).to eq(5)
          expect(summary[:reserved_route_ports_limit]).to eq(2)
          expect(summary[:log_rate_limit]).to eq(500)
        end
      end
    end
  end
end
