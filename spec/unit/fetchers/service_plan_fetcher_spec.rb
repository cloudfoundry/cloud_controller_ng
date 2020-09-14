require 'db_spec_helper'
require 'fetchers/service_plan_fetcher'

module VCAP::CloudController
  RSpec.describe ServicePlanFetcher do
    let!(:plan_1) { ServicePlan.make }
    let!(:plan_2) { ServicePlan.make }
    let!(:plan_3) { ServicePlan.make }

    context 'when the plan does not exist' do
      it 'returns nil' do
        returned_service_plan = ServicePlanFetcher.fetch('no-such-guid')
        expect(returned_service_plan).to be_nil
      end
    end

    context 'when the service plan exists' do
      it 'returns the correct service plan' do
        returned_service_plan = ServicePlanFetcher.fetch(plan_2.guid)
        expect(returned_service_plan).to eq(plan_2)
      end
    end
  end
end
