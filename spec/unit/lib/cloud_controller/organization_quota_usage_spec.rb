require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaUsage do
    let!(:org) { Organization.make }
    let!(:org_usage) { OrganizationQuotaUsage.new(org) }
    let!(:space1) { Space.make(organization: org) }
    let!(:space2) { Space.make }
    let!(:space3) { Space.make(organization: org) }

    describe '#routes' do
      let!(:route) { Route.make(space: space1) }
      let!(:route2) { Route.make(space: space1) }
      let!(:route3) { Route.make(space: space2) }
      let!(:route4) { Route.make(space: space3) }

      it 'returns the number of routes in all spaces under the org' do
        result_routes = org_usage.routes
        expect(result_routes).to eq(3)
      end
    end

    describe '#service_instances' do
      let!(:service_instance) { ServiceInstance.make(space: space1, is_gateway_service: true) }
      let!(:service_instance2) { ServiceInstance.make(space: space1, is_gateway_service: true) }
      let!(:service_instance3) { ServiceInstance.make(space: space2, is_gateway_service: true) }
      let!(:service_instance4) { ServiceInstance.make(space: space3, is_gateway_service: true) }

      it 'returns the number of service instances for all spaces under the org' do
        result_service_instances = org_usage.service_instances
        expect(result_service_instances).to eq(3)
      end
    end

    describe '#private_domains' do
      let!(:org2) { Organization.make }
      let!(:domain) { Domain.make(owning_organization: org) }
      let!(:domain2) { Domain.make(owning_organization: org) }
      let!(:domain3) { Domain.make(owning_organization: org2) }
      let!(:domain4) { Domain.make(owning_organization: org) }

      it 'returns the number of domains for all spaces under the org' do
        result_domains = org_usage.private_domains
        expect(result_domains).to eq(3)
      end
    end

    describe '#service_keys' do
      let!(:service_instance) { ServiceInstance.make(space: space1) }
      let!(:service_instance2) { ServiceInstance.make(space: space1) }
      let!(:service_instance3) { ServiceInstance.make(space: space2) }
      let!(:service_instance4) { ServiceInstance.make(space: space3) }
      let!(:service_key) { ServiceKey.make(service_instance_id: service_instance.id) }
      let!(:service_key2) { ServiceKey.make(service_instance_id: service_instance2.id) }
      let!(:service_key3) { ServiceKey.make(service_instance_id: service_instance3.id) }
      let!(:service_key4) { ServiceKey.make(service_instance_id: service_instance4.id) }

      it 'returns the number of service keys for all spaces under the org' do
        result_service_keys = org_usage.service_keys
        expect(result_service_keys).to eq(3)
      end
    end

    describe '#reserved_route_ports' do
      let!(:domain) { SharedDomain.make(router_group_guid: 'some-router-group') }
      let!(:routing_api_client) { instance_double(RoutingApi::Client) }
      let!(:router_group) { instance_double(RoutingApi::RouterGroup) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(routing_api_client)
        allow(routing_api_client).to receive(:router_group).and_return(router_group)
        allow(routing_api_client).to receive_messages(router_group: router_group, enabled?: true)
        allow(router_group).to receive_messages(type: 'tcp', reservable_ports: [1234, 2, 2345, 3])
      end

      let!(:route) { Route.make(domain: domain, host: '', port: 1234, space: space1) }
      let!(:route2) { Route.make(domain: domain, host: '', port: 2, space: space2) }
      let!(:route3) { Route.make(domain: domain, host: '', port: 2345, space: space1) }
      let!(:route4) { Route.make(domain: domain, host: '', port: 3, space: space3) }

      it 'returns the number of ports for all spaces under the org' do
        result_ports = org_usage.reserved_route_ports
        expect(result_ports).to eq(3)
      end
    end

    describe '#app_tasks' do
      let!(:app) { VCAP::CloudController::AppModel.make(space: space1) }
      let!(:app2) { VCAP::CloudController::AppModel.make(space: space1) }
      let!(:app3) { VCAP::CloudController::AppModel.make(space: space2) }
      let!(:app4) { VCAP::CloudController::AppModel.make(space: space3) }
      let!(:droplet) do
        VCAP::CloudController::DropletModel.make(
          app_guid: app.guid,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: true, error_message: nil)
        app.droplet = droplet
        app.save
      end

      let!(:task) do
        VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app.guid,
          droplet: app.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::RUNNING_STATE
        )
      end
      let!(:task2) do
        VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app2.guid,
          droplet: app.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::RUNNING_STATE
        )
      end
      let!(:task3) do
        VCAP::CloudController::TaskModel.make(
          name: 'task false',
          command: 'echo task',
          app_guid: app3.guid,
          droplet: app.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::RUNNING_STATE
        )
      end
      let!(:task4) do
        VCAP::CloudController::TaskModel.make(
          name: 'task three',
          command: 'echo task',
          app_guid: app4.guid,
          droplet: app.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::RUNNING_STATE
        )
      end

      it 'returns the number of service keys for all spaces under the org' do
        result_per_app_tasks = org_usage.app_tasks
        expect(result_per_app_tasks).to eq(3)
      end
    end
  end
end
