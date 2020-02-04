require 'spec_helper'
require 'fetchers/service_plan_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServicePlanListFetcher do
    describe '#fetch_public' do
      context 'when there are no service plans' do
        it 'is empty' do
          service_plans = ServicePlanListFetcher.new.fetch_public.all
          expect(service_plans).to be_empty
        end
      end

      context 'when there are no public service plan' do
        let!(:service_plan_1) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_2) { ServicePlan.make(public: false, active: true) }

        it 'is empty' do
          service_plans = ServicePlanListFetcher.new.fetch_public.all
          expect(service_plans).to be_empty
        end
      end

      context 'when there are public service plans' do
        let!(:service_plan_1) { ServicePlan.make(public: true, active: true) }
        let!(:service_plan_2) { ServicePlan.make(public: true, active: true) }

        it 'lists them all' do
          service_plans = ServicePlanListFetcher.new.fetch_public.all
          expect(service_plans).to contain_exactly(service_plan_1, service_plan_2)
        end
      end
    end
  end
end
