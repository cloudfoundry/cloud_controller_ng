require 'db_spec_helper'
require 'fetchers/service_offering_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceOfferingFetcher do
    let!(:offering_1) { Service.make }
    let!(:offering_2) { Service.make }
    let!(:offering_3) { Service.make }

    context 'when the offering does not exist' do
      it 'returns nil' do
        returned_service_offering = ServiceOfferingFetcher.fetch('no-such-guid')
        expect(returned_service_offering).to be_nil
      end
    end

    context 'when the service offering exists' do
      it 'returns the correct service offering' do
        returned_service_offering = ServiceOfferingFetcher.fetch(offering_2.guid)
        expect(returned_service_offering).to eq(offering_2)
      end
    end
  end
end
