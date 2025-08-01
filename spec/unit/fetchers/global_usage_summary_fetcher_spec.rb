require 'spec_helper'

module VCAP::CloudController
  RSpec.describe GlobalUsageSummaryFetcher do
    subject(:fetcher) { GlobalUsageSummaryFetcher }

    describe '.summary' do
      before do
        router_group = double('router_group', type: 'tcp', reservable_ports: [8080])
        routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
        allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client:))
      end

      let!(:org) { Organization.make }
      let!(:space) { Space.make(organization: org) }
      let!(:completed_task) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE, memory_in_mb: 100) }
      let!(:running_task) { TaskModel.make(state: TaskModel::RUNNING_STATE, memory_in_mb: 100) }
      let!(:started_process1) { ProcessModelFactory.make(instances: 3, state: 'STARTED', memory: 100) }
      let!(:started_process2) { ProcessModelFactory.make(instances: 6, state: 'STARTED', memory: 100) }
      let!(:started_process3) { ProcessModelFactory.make(instances: 7, state: 'STARTED', memory: 100) }
      let!(:stopped_process) { ProcessModelFactory.make(instances: 2, state: 'STOPPED', memory: 100) }
      let!(:process2) { ProcessModelFactory.make(instances: 5, state: 'STARTED', memory: 100) }
      let!(:service_instance1) { ServiceInstance.make(is_gateway_service: false) }
      let!(:service_instance2) { ServiceInstance.make(is_gateway_service: true) }
      let!(:service_instance3) { ServiceInstance.make(is_gateway_service: true) }
      let!(:service_key1) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance1) }
      let!(:service_key2) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance2) }
      let!(:shared_domain_with_router_group) { SharedDomain.make(router_group_guid: 'rg-123') }
      let!(:shared_domain_without_router_group) { SharedDomain.make(router_group_guid: nil) }
      let!(:private_domain_without_router_group) { PrivateDomain.make(owning_organization: org) }
      let!(:route1) { Route.make(host: '', domain: shared_domain_with_router_group, port: 8080) }
      let!(:route2) { Route.make(host: '', domain: private_domain_without_router_group, space: space) }

      it 'returns a summary' do
        summary = fetcher.summary

        expect(summary.started_instances).to eq(21)
        expect(summary.memory_in_mb).to eq(2200)
        expect(summary.routes).to eq(2)
        expect(summary.service_instances).to eq(2)
        expect(summary.reserved_ports).to eq(1)
        expect(summary.domains).to eq(2) # system domain "vcap.me" plus :private_domain_without_router_group
        expect(summary.per_app_tasks).to eq(1)
        expect(summary.service_keys).to eq(2)
      end
    end
  end
end
