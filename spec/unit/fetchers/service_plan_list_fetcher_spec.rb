require 'spec_helper'
require 'fetchers/service_plan_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServicePlanListFetcher do
    describe '#fetch' do
      context 'when there are no plans' do
        it 'is empty' do
          service_plans = ServicePlanListFetcher.new.fetch.all
          expect(service_plans).to be_empty
        end
      end

      context 'when there are plans' do
        let!(:public_plan_1) { make_public_plan }
        let!(:public_plan_2) { make_public_plan }

        let!(:private_plan_1) { make_private_plan }
        let!(:private_plan_2) { make_private_plan }

        let(:space_1) { Space.make }
        let(:space_2) { Space.make }
        let(:space_3) { Space.make }
        let!(:space_scoped_plan_1) { make_space_scoped_plan(space_1) }
        let!(:space_scoped_plan_2) { make_space_scoped_plan(space_2) }
        let!(:space_scoped_plan_3) { make_space_scoped_plan(space_3) }
        let!(:space_scoped_plan_4) { make_space_scoped_plan(space_3) }

        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }
        let(:org_3) { Organization.make }
        let!(:org_restricted_plan_1) { make_org_restricted_plan(org_1) }
        let!(:org_restricted_plan_2) { make_org_restricted_plan(org_2) }
        let!(:org_restricted_plan_3) { make_org_restricted_plan(org_3) }
        let!(:org_restricted_plan_4) { make_org_restricted_plan(org_3) }

        it 'only fetches public plans' do
          service_plans = ServicePlanListFetcher.new.fetch.all
          expect(service_plans).to contain_exactly(public_plan_1, public_plan_2)
        end

        context 'when the `omniscient` flag is true' do
          it 'fetches all plans' do
            service_plans = ServicePlanListFetcher.new.fetch(omniscient: true).all
            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              private_plan_1,
              private_plan_2,
              space_scoped_plan_1,
              space_scoped_plan_2,
              space_scoped_plan_3,
              space_scoped_plan_4,
              org_restricted_plan_1,
              org_restricted_plan_2,
              org_restricted_plan_3,
              org_restricted_plan_4,
            )
          end
        end

        context 'when `space_guids` are specified' do
          it 'includes public plans and ones for those spaces' do
            service_plans = ServicePlanListFetcher.new.fetch(space_guids: [space_1.guid, space_3.guid]).all
            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              space_scoped_plan_1,
              space_scoped_plan_3,
              space_scoped_plan_4,
            )
          end
        end

        context 'when `org_guids` are specified' do
          it 'includes public plans and ones for those orgs' do
            service_plans = ServicePlanListFetcher.new.fetch(org_guids: [org_1.guid, org_3.guid]).all
            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              org_restricted_plan_1,
              org_restricted_plan_3,
              org_restricted_plan_4,
            )
          end
        end

        context 'when both `pace_guids` and `org_guids` are specified' do
          it 'includes public plans, ones for those spaces and ones for those orgs' do
            service_plans = ServicePlanListFetcher.new.fetch(
              space_guids: [space_3.guid],
              org_guids: [org_3.guid],
            ).all

            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              space_scoped_plan_3,
              space_scoped_plan_4,
              org_restricted_plan_3,
              org_restricted_plan_4,
            )
          end
        end
      end

      def make_public_plan
        ServicePlan.make(public: true, active: true)
      end

      def make_private_plan
        ServicePlan.make(public: false, active: true)
      end

      def make_space_scoped_plan(space)
        service_broker = ServiceBroker.make(space: space)
        service_offering = Service.make(service_broker: service_broker)
        ServicePlan.make(service: service_offering)
      end

      def make_org_restricted_plan(org)
        service_plan = ServicePlan.make(public: false)
        ServicePlanVisibility.make(organization: org, service_plan: service_plan)
        service_plan
      end
    end
  end
end
