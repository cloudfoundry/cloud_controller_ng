require 'spec_helper'
require 'presenters/v3/service_plan_visibility_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServicePlanVisibilityPresenter do
  describe '#to_hash' do
    let(:result) { described_class.new(service_plan, []).to_hash.deep_symbolize_keys }

    context 'when service plan is public' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(public: true)
      end

      it 'should return type public' do
        expect(result).to eq({
          type: 'public'
        })
      end
    end

    context 'when service plan is space scoped' do
      let(:space) do
        VCAP::CloudController::Space.make
      end

      let!(:service_plan) do
        broker = VCAP::CloudController::ServiceBroker.make(space: space)
        offering = VCAP::CloudController::Service.make(service_broker: broker)
        VCAP::CloudController::ServicePlan.make(public: false, service: offering)
      end

      it 'should return type space' do
        expect(result).to eq({
          type: 'space',
          space: {
            guid: space.guid,
            name: space.name
          }
        })
      end
    end

    context 'when service plan is visible for admin only' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(public: false)
      end

      it 'should return type admin' do
        expect(result).to eq({
          type: 'admin'
        })
      end
    end

    context 'when service plan is visible for a set of orgs only' do
      let(:service_plan) do
        plan = VCAP::CloudController::ServicePlan.make(public: false)
        VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan, organization: org)
        plan
      end

      let(:org) do
        VCAP::CloudController::Organization.make
      end

      let(:result) { described_class.new(service_plan, [org]).to_hash.deep_symbolize_keys }

      it 'should return type organization' do
        expect(result).to eq({
          type: 'organization',
          organizations: [
            {
              guid: org.guid,
              name: org.name
            }
          ]
        })
      end
    end
  end
end
