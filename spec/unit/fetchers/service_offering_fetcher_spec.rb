require 'spec_helper'
require 'fetchers/service_offering_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceOfferingFetcher do
    let!(:offering_1) { Service.make }
    let!(:offering_2) { Service.make }
    let!(:offering_3) { Service.make }

    context 'when the offering does not exist' do
      it 'returns nil and is not public' do
        returned_service_offering = ServiceOfferingFetcher.fetch('no-such-guid')
        expect(returned_service_offering).to be_nil
      end
    end

    context 'when the service offering exists and has no plans' do
      it 'returns the correct service offering, nil space, and is not public' do
        returned_service_offering = ServiceOfferingFetcher.fetch(offering_2.guid)
        expect(returned_service_offering).to eq(offering_2)
      end
    end

    context 'when the service offering exists and has private plans' do
      let!(:private_plan_1) { ServicePlan.make(service: offering_1, public: false) }
      let!(:private_plan_2) { ServicePlan.make(service: offering_1, public: false) }

      it 'returns the correct service offering, nil space, and is not public' do
        returned_service_offering = ServiceOfferingFetcher.fetch(offering_1.guid)
        expect(returned_service_offering).to eq(offering_1)
      end
    end

    context 'when the service offering exists and has a public plan' do
      let!(:private_plan_3) { ServicePlan.make(service: offering_3, public: false) }
      let!(:public_plan_1) { ServicePlan.make(service: offering_3, public: true) }

      it 'returns the correct service offering, nil space, and is public' do
        returned_service_offering = ServiceOfferingFetcher.fetch(offering_3.guid)
        expect(returned_service_offering).to eq(offering_3)
      end
    end

    context 'when the service offering comes from a space-scoped service broker' do
      let!(:broker_org) { VCAP::CloudController::Organization.make }
      let!(:broker_space) { VCAP::CloudController::Space.make(organization: broker_org) }
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: broker_space) }
      let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let!(:private_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

      it 'returns the correct service offering and the space' do
        returned_service_offering = ServiceOfferingFetcher.fetch(service_offering.guid)
        expect(returned_service_offering).to eq(service_offering)
      end
    end
  end
end
