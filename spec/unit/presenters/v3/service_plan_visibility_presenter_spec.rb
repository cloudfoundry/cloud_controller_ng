require 'db_spec_helper'
require 'presenters/v3/service_plan_visibility_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServicePlanVisibilityPresenter do
  describe '#to_hash' do
    let(:visible_in_orgs) { [] }
    let(:result) { described_class.new(service_plan, visible_in_orgs).to_hash.deep_symbolize_keys }

    context 'when service plan is public' do
      let(:service_plan) do
        create(:service_plan, public: true)
      end

      it 'returns type public' do
        expect(result).to eq({
                               type: 'public'
                             })
      end
    end

    context 'when service plan is space scoped' do
      let(:space) do
        create(:space)
      end

      let!(:service_plan) do
        broker = create(:service_broker, space:)
        offering = create(:service, service_broker: broker)
        create(:service_plan, public: false, service: offering)
      end

      it 'returns type space' do
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
        create(:service_plan, public: false)
      end

      it 'returns type admin' do
        expect(result).to eq({
                               type: 'admin'
                             })
      end
    end

    context 'when service plan is visible for a set of orgs only' do
      let(:service_plan) do
        create(:service_plan, public: false) do |plan|
          create(:service_plan_visibility, service_plan: plan, organization: org_1)
          create(:service_plan_visibility, service_plan: plan, organization: org_2)
        end
      end

      let(:org_1) { create(:organization) }
      let(:org_2) { create(:organization) }
      let(:visible_in_orgs) { [org_1, org_2] }

      it 'returns type organization' do
        expect(result).to eq({
                               type: 'organization',
                               organizations: [
                                 {
                                   guid: org_1.guid,
                                   name: org_1.name
                                 },
                                 {
                                   guid: org_2.guid,
                                   name: org_2.name
                                 }
                               ]
                             })
      end

      context 'when the list of orgs is empty' do
        let(:visible_in_orgs) { [] }

        it 'returns an empty list' do
          expect(result).to eq({
                                 type: 'organization',
                                 organizations: []
                               })
        end
      end

      context 'when the list of orgs is omitted' do
        let(:visible_in_orgs) { nil }

        it 'returns the type and omit the list' do
          expect(result).to eq({
                                 type: 'organization'
                               })
        end
      end
    end
  end
end
