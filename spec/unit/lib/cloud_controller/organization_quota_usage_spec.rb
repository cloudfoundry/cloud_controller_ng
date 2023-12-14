require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaUsage do
    let(:org) { Organization.make }
    let(:space1) { Space.make(organization: org) }
    let(:space2) { Space.make }
    let(:space3) { Space.make(organization: org) }

    subject(:org_usage) { OrganizationQuotaUsage.new(org) }

    describe '#routes' do
      before do
        [space1, space1, space2, space3].each { |s| Route.make(space: s) }
      end

      it 'returns the number of routes in all spaces under the org' do
        expect(org_usage.routes).to eq(3)
      end
    end

    describe '#service_instances' do
      before do
        [space1, space1, space2, space3].each { |s| ManagedServiceInstance.make(space: s) }
        UserProvidedServiceInstance.make(space: space1)
      end

      it 'returns the number of service instances in all spaces under the org' do
        expect(org_usage.service_instances).to eq(3)
      end
    end

    describe '#private_domains' do
      before do
        [space1, space1, space2, space3].each { |s| Domain.make(owning_organization: s.organization) }
      end

      it 'returns the number of private domains in all spaces under the org' do
        expect(org_usage.private_domains).to eq(3)
      end
    end

    describe '#service_keys' do
      before do
        [space1, space1, space2, space3].each { |s| ServiceKey.make(service_instance: ServiceInstance.make(space: s)) }
      end

      it 'returns the number of service keys in all spaces under the org' do
        expect(org_usage.service_keys).to eq(3)
      end
    end

    describe '#reserved_route_ports' do
      before do
        reservable_ports = [1234, 2, 2345, 3]
        router_group = instance_double(RoutingApi::RouterGroup, type: 'tcp', reservable_ports: reservable_ports)
        routing_api_client = instance_double(RoutingApi::Client, router_group: router_group, enabled?: true)
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(routing_api_client)
        domain = SharedDomain.make(router_group_guid: 'some-router-group')
        [space1, space1, space2, space3].each_with_index { |s, i| Route.make(space: s, domain: domain, host: '', port: reservable_ports[i]) }
      end

      it 'returns the number of reserved route ports in all spaces under the org' do
        expect(org_usage.reserved_route_ports).to eq(3)
      end
    end

    describe '#app_tasks' do
      before do
        [space1, space1, space2, space3].each { |s| TaskModel.make(app: AppModel.make(space: s), state: TaskModel::RUNNING_STATE) }
        TaskModel.make(app: AppModel.make(space: space1), state: TaskModel::PENDING_STATE)
        TaskModel.make(app: AppModel.make(space: space1), state: TaskModel::CANCELING_STATE)
      end

      it 'returns the number of app tasks in all spaces under the org' do
        expect(org_usage.app_tasks).to eq(4)
      end
    end
  end
end
