require 'spec_helper'
require 'fetchers/service_plan_visibility_fetcher'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibilityFetcher do
    context 'when a specified plan has no visibility' do
      let(:plan) { ServicePlan.make }
      let(:org) { Organization.make }

      it 'is not visible' do
        expect(ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?([plan.guid], [org.guid])).to eq(false)
      end
    end

    context 'when a specified plan has visibility in a specified org' do
      let(:plan) { ServicePlan.make }
      let(:org) { Organization.make }
      let!(:visibility) { ServicePlanVisibility.make(organization: org, service_plan: plan) }

      it 'is visible' do
        expect(ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?([plan.guid], [org.guid])).to eq(true)
      end
    end

    context 'when a specified plan has visibility in other org' do
      let(:plan) { ServicePlan.make }
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }
      let(:org3) { Organization.make }
      let!(:visibility) { ServicePlanVisibility.make(organization: org3, service_plan: plan) }

      it 'is not visible' do
        expect(ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?([plan.guid], [org1.guid, org2.guid])).to eq(false)
      end
    end

    context 'when many plans are specified and only one has visibility in a specified org' do
      let(:plan1) { ServicePlan.make }
      let(:plan2) { ServicePlan.make }
      let(:plan3) { ServicePlan.make }
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }
      let(:org3) { Organization.make }
      let!(:visibility) { ServicePlanVisibility.make(organization: org3, service_plan: plan2) }

      it 'is visible' do
        expect(ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?([plan1.guid, plan2.guid, plan3.guid], [org2.guid, org3.guid])).to eq(true)
      end
    end
  end
end
