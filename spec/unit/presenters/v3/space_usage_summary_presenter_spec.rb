require 'spec_helper'
require 'presenters/v3/space_usage_summary_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpaceUsageSummaryPresenter do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }

    context 'empty space' do
      describe '#to_hash' do
        let(:result) { SpaceUsageSummaryPresenter.new(space).to_hash }

        it 'presents the space usage summary as json' do
          expect(result[:usage_summary][:started_instances]).to eq(0)
          expect(result[:usage_summary][:memory_in_mb]).to eq(0)
          expect(result[:usage_summary][:routes]).to eq(0)
          expect(result[:usage_summary][:service_instances]).to eq(0)
          expect(result[:usage_summary][:reserved_ports]).to eq(0)
          expect(result[:usage_summary][:domains]).to eq(0)
          expect(result[:usage_summary][:per_app_tasks]).to eq(0)
          expect(result[:usage_summary][:service_keys]).to eq(0)

          expect(result[:links][:self][:href]).to match(%r{/v3/spaces/#{space.guid}/usage_summary$})
          expect(result[:links][:space][:href]).to match(%r{/v3/spaces/#{space.guid}$})
        end
      end
    end

    context 'space with instances, routes and services' do
      before do
        router_group = double('router_group', type: 'tcp', reservable_ports: [4444])
        routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
        allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client:))
      end

      let(:app_model) { VCAP::CloudController::AppModel.make(name: 'App Model', space: space) }
      let!(:process) { VCAP::CloudController::ProcessModel.make(:process, state: VCAP::CloudController::ProcessModel::STARTED, memory: 512, app: app_model) }
      let!(:task) { VCAP::CloudController::TaskModel.make(app: app_model, state: VCAP::CloudController::TaskModel::RUNNING_STATE, memory_in_mb: 512) }
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: '123') }
      let!(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
      let!(:route) { VCAP::CloudController::Route.make(host: '', domain: shared_domain, space: space, port: 4444) }
      let(:broker) { VCAP::CloudController::ServiceBroker.make }
      let(:service) { VCAP::CloudController::Service.make(service_broker: broker) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service, public: true) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:) }
      let!(:service_key) { VCAP::CloudController::ServiceKey.make(service_instance:) }

      describe '#to_hash' do
        let(:result) { SpaceUsageSummaryPresenter.new(space).to_hash }

        it 'presents the space usage summary as json' do
          expect(result[:usage_summary][:started_instances]).to eq(1)
          expect(result[:usage_summary][:memory_in_mb]).to eq(1024)
          expect(result[:usage_summary][:routes]).to eq(1)
          expect(result[:usage_summary][:service_instances]).to eq(1)
          expect(result[:usage_summary][:reserved_ports]).to eq(1)
          expect(result[:usage_summary][:domains]).to eq(1)
          expect(result[:usage_summary][:per_app_tasks]).to eq(1)
          expect(result[:usage_summary][:service_keys]).to eq(1)

          expect(result[:links][:self][:href]).to match(%r{/v3/spaces/#{space.guid}/usage_summary$})
          expect(result[:links][:space][:href]).to match(%r{/v3/spaces/#{space.guid}$})
        end
      end
    end
  end
end
