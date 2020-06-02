require 'spec_helper'
require 'presenters/v3/space_quota_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpaceQuotaPresenter do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:visible_space_guids) { [space_1.guid, space_2.guid] }

    let(:space_quota) do
      VCAP::CloudController::SpaceQuotaDefinition.make(
        guid: 'quota-guid',
        organization: org,
        memory_limit: 2,
        instance_memory_limit: 3,
        app_instance_limit: 4,
        app_task_limit: 5,
        non_basic_services_allowed: false,
        total_services: 6,
        total_service_keys: 7,
        total_routes: 7,
        total_reserved_route_ports: 2,
      )
    end

    before do
      space_quota.add_space(space_1)
      space_quota.add_space(space_2)
    end

    describe '#to_hash' do
      let(:result) { SpaceQuotaPresenter.new(space_quota, visible_space_guids: visible_space_guids).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(space_quota.guid)
        expect(result[:created_at]).to eq(space_quota.created_at)
        expect(result[:updated_at]).to eq(space_quota.updated_at)
        expect(result[:name]).to eq(space_quota.name)
        expect(result[:apps][:total_memory_in_mb]).to eq(space_quota.memory_limit)
        expect(result[:apps][:per_process_memory_in_mb]).to eq(space_quota.instance_memory_limit)
        expect(result[:apps][:total_instances]).to eq(space_quota.app_instance_limit)
        expect(result[:apps][:per_app_tasks]).to eq(space_quota.app_task_limit)
        expect(result[:services][:paid_services_allowed]).to eq(space_quota.non_basic_services_allowed)
        expect(result[:services][:total_service_instances]).to eq(space_quota.total_services)
        expect(result[:services][:total_service_keys]).to eq(space_quota.total_service_keys)
        expect(result[:routes][:total_routes]).to eq(space_quota.total_routes)
        expect(result[:routes][:total_reserved_ports]).to eq(space_quota.total_reserved_route_ports)

        expect(result[:relationships][:organization][:data][:guid]).to eq(org.guid)
        expect(result[:relationships][:spaces][:data]).to match_array([
          { guid: space_1.guid },
          { guid: space_2.guid }
        ])

        expect(result[:links][:self][:href]).to match(%r{/v3/space_quotas/#{space_quota.guid}$})
        expect(result[:links][:organization][:href]).to match(%r{/v3/organizations/#{org.guid}$})
      end

      context 'when using null values' do
        let(:space_quota) do
          VCAP::CloudController::SpaceQuotaDefinition.make(
            guid: 'quota-guid',
            organization: org,
            memory_limit: -1,
            instance_memory_limit: -1,
            app_instance_limit: -1,
            app_task_limit: -1,
            total_services: -1,
            total_service_keys: -1,
            total_routes: -1,
            total_reserved_route_ports: -1
          )
        end

        it "properly converts -1 sentinel values to JSON's null" do
          expect(result[:apps][:total_memory_in_mb]).to be_nil
          expect(result[:apps][:per_process_memory_in_mb]).to be_nil
          expect(result[:apps][:total_instances]).to be_nil
          expect(result[:apps][:per_app_tasks]).to be_nil
          expect(result[:services][:total_service_instances]).to be_nil
          expect(result[:services][:total_service_keys]).to be_nil
          expect(result[:routes][:total_routes]).to be_nil
          expect(result[:routes][:total_reserved_ports]).to be_nil
        end
      end
    end
  end
end
