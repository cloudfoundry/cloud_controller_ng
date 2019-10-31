require 'spec_helper'
require 'fetchers/service_offerings_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceOfferingsFetcher do
    let!(:offering_1) { Service.make }
    let!(:offering_2) { Service.make }
    let!(:offering_3) { Service.make }

    let!(:org_1) { Organization.make }
    let!(:org_2) { Organization.make }
    let!(:org_3) { Organization.make }

    describe '#fetch_one(guid)' do
      context 'when the specified GUID does not match any existing offerings' do
        it 'returns nil' do
          expect(ServiceOfferingsFetcher.fetch_one('does-not-exist')).to be_nil
        end
      end

      context 'when the specified GUID matches an existing offering' do
        it 'returns the service offering' do
          expect(ServiceOfferingsFetcher.fetch_one(offering_2.guid)).to eq(offering_2)
        end
      end
    end

    describe '#fetch_one(guid, org_guids:)' do
      let(:plan) { ServicePlan.make(public: false) }
      let(:offering) { plan.service }
      let!(:visibility) { ServicePlanVisibility.make(service_plan: plan, organization: org_2) }

      context 'when empty org_guids are provided' do
        it 'returns nil' do
          expect(ServiceOfferingsFetcher.fetch_one(offering_1.guid, org_guids: [])).to be_nil
        end
      end

      context 'when offering is visible in one of the orgs' do
        let(:org_guids) { [org_1.guid, org_2.guid, org_3.guid] }

        it 'returns that offering' do
          expect(ServiceOfferingsFetcher.fetch_one(offering.guid, org_guids: org_guids)).to eq(offering)
        end
      end

      context 'when offering is not visible in any of the orgs' do
        let(:org_guids) { [org_1.guid, org_2.guid] }

        it 'returns nil' do
          expect(ServiceOfferingsFetcher.fetch_one(offering_3.guid, org_guids: org_guids)).to be_nil
        end
      end

      context 'when the specified plan is public' do
        let(:plan) { ServicePlan.make(public: true) }
        let(:org_guids) { [org_1.guid, org_3.guid] }

        it 'returns the service offering even if org guids is empty' do
          expect(ServiceOfferingsFetcher.fetch_one(offering.guid, org_guids: [])).to eq(offering)
        end

        it 'returns the service offering even if org guids does not include where it is enabled' do
          expect(ServiceOfferingsFetcher.fetch_one(offering.guid, org_guids: org_guids)).to eq(offering)
        end
      end

      context 'when there are no service plan visibilites' do
        let(:plan) { ServicePlan.make(public: true) }
        let(:offering) { plan.service }
        let(:visibility) {}

        it 'returns the service offering' do
          expect(ServiceOfferingsFetcher.fetch_one(offering.guid, org_guids: [])).to eq(offering)
        end
      end
    end

    describe '#fetch_one_anonymously(guid)' do
      let(:plan) { ServicePlan.make(public: true) }
      let(:offering) { plan.service }

      context 'when the specified GUID does not match any existing offerings' do
        it 'returns nil' do
          expect(ServiceOfferingsFetcher.fetch_one_anonymously('does-not-exist')).to be_nil
        end
      end

      context 'when the specified GUID matches an existing offering' do
        it 'returns the service offering' do
          expect(ServiceOfferingsFetcher.fetch_one_anonymously(offering.guid)).to eq(offering)
        end
      end

      context 'when the specified GUID matches a non-public service offering' do
        let(:private_plan) { ServicePlan.make(public: false) }
        let(:private_offering) { private_plan.service }

        it 'returns nil' do
          expect(ServiceOfferingsFetcher.fetch_one_anonymously(private_offering.guid)).to be_nil
        end
      end
    end
  end
end
