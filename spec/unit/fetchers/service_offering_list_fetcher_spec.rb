require 'spec_helper'
require 'fetchers/service_offering_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceOfferingListFetcher do
    describe '#fetch_all' do
      context 'when there are no service offerings' do
        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_all.all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public, non-public and space-scoped service offerings' do
        let!(:public_service_offering) { ServicePlan.make(public: true, active: true).service }

        let!(:non_public_service_offering) { ServicePlan.make(public: false, active: true).service }

        let!(:space_scoped_service_broker) { ServiceBroker.make(space: Space.make) }
        let!(:space_scoped_service_offering) { Service.make(service_broker: space_scoped_service_broker) }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_all.all
          expect(service_offerings).to contain_exactly(public_service_offering, non_public_service_offering, space_scoped_service_offering)
        end
      end
    end

    describe '#fetch_public' do
      context 'when there are no public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: false, active: true).service }

        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public.all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: true, active: true).service }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public.all

          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2)
        end
      end

      context 'uniqueness of service offerings' do
        let(:service_offering) { Service.make }

        before do
          2.times { ServicePlan.make(service: service_offering, public: true, active: true) }
        end

        it 'de-duplicates service offerings' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public.all

          expect(service_offerings).to contain_exactly(service_offering)
        end
      end
    end

    describe '#fetch' do
      context 'when there are no service offerings' do
        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch([], []).all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: true, active: true).service }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch([], []).all

          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2)
        end
      end

      context 'when there are service offerings that are only visible in certain orgs' do
        let!(:organization_1) { Organization.make }
        let!(:organization_2) { Organization.make }
        let!(:service_plan_1) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_2) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_3) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_4) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_1) { service_plan_1.service }
        let!(:service_offering_2) { service_plan_2.service }
        let!(:service_offering_3) { service_plan_3.service }
        let!(:service_offering_4) { service_plan_4.service }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2, organization: organization_1) }
        let!(:visibility_3) { ServicePlanVisibility.make(service_plan: service_plan_3, organization: organization_2) }
        let!(:visibility_4) { ServicePlanVisibility.make(service_plan: service_plan_4, organization: organization_1) }

        it 'lists the ones that are visible in the specified orgs' do
          service_offerings_1 = ServiceOfferingListFetcher.new.fetch([organization_1.guid], []).all
          expect(service_offerings_1).to contain_exactly(service_offering_2, service_offering_4)

          service_offerings_2 = ServiceOfferingListFetcher.new.fetch([organization_1.guid, organization_2.guid], []).all
          expect(service_offerings_2).to contain_exactly(service_offering_2, service_offering_3, service_offering_4)
        end
      end

      context 'when there are service offerings from a space-scoped broker' do
        let!(:space_1) { Space.make }
        let!(:space_2) { Space.make }

        let!(:service_offering_1) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_3) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_4) { ServicePlan.make(public: false, active: true).service }

        before do
          service_offering_1.service_broker.space = space_1
          service_offering_1.service_broker.save
          service_offering_2.service_broker.space = space_1
          service_offering_2.service_broker.save
          service_offering_3.service_broker.space = space_2
          service_offering_3.service_broker.save
        end

        it 'lists the ones visible in the specified spaces' do
          service_offerings_1 = ServiceOfferingListFetcher.new.fetch([], [space_1.guid]).all
          expect(service_offerings_1).to contain_exactly(service_offering_1, service_offering_2)

          service_offerings_2 = ServiceOfferingListFetcher.new.fetch([], [space_1.guid, space_2.guid]).all
          expect(service_offerings_2).to contain_exactly(service_offering_1, service_offering_2, service_offering_3)
        end
      end

      context 'when there is a mixture of service offerings' do
        # public - can see
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }

        # non public - cannot see
        let!(:service_offering_2) { ServicePlan.make(public: false, active: true).service }

        # visible in org 1 - can see
        let!(:org_1) { Organization.make }
        let!(:org_2) { Organization.make }
        let!(:service_plan_1) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_3) { service_plan_1.service }
        let!(:visibility_1) { ServicePlanVisibility.make(service_plan: service_plan_1, organization: org_1) }

        # visbible in org 3 - cannot see
        let!(:org_3) { Organization.make }
        let!(:service_plan_2) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_4) { service_plan_1.service }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2, organization: org_3) }

        let!(:space_1) { Space.make }
        let!(:space_2) { Space.make }
        let!(:space_3) { Space.make }
        let!(:service_offering_5) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_6) { ServicePlan.make(public: false, active: true).service }
        before do
          service_offering_5.service_broker.space = space_1 # visible if member of space 1 - can see
          service_offering_5.service_broker.save
          service_offering_6.service_broker.space = space_2 # visible if member of space 2 - cannot see
          service_offering_6.service_broker.save
        end

        it 'lists the visible ones' do
          service_offerings = ServiceOfferingListFetcher.new.fetch([org_1.guid, org_2.guid], [space_1.guid, space_3.guid]).all
          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_3, service_offering_5)
        end
      end

      context 'uniqueness of service offerings' do
        let!(:organization_1) { Organization.make }
        let!(:organization_2) { Organization.make }
        let!(:service_plan) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering) { service_plan.service }
        let!(:visibility_1) { ServicePlanVisibility.make(service_plan: service_plan, organization: organization_1) }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan, organization: organization_2) }

        it 'de-duplicates service offerings' do
          service_offerings = ServiceOfferingListFetcher.new.fetch([organization_1.guid, organization_2.guid], []).all
          expect(service_offerings).to contain_exactly(service_offering)
        end
      end
    end
  end
end
