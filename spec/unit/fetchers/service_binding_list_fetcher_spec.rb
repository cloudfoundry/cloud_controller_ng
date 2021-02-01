require 'spec_helper'
require 'fetchers/service_binding_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceBindingListFetcher do
    let(:fetcher) { ServiceBindingListFetcher }

    describe '#fetch_service_instance_bindings_in_space' do
      let(:space) { Space.make }
      let(:service_instance) { ServiceInstance.make(space: space) }

      it 'returns a Sequel::Dataset' do
        results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
        expect(results).to be_a(Sequel::Dataset)
      end

      context 'when there are no bindings' do
        it 'returns an empty dataset' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to eql(0)
        end
      end

      context 'when a binding exists in a space' do
        let!(:service_binding) { ServiceBinding.make(app: AppModel.make(space: space), service_instance: service_instance) }
        let!(:other_service_binding) { ServiceBinding.make }

        it 'returns the binding for the correct space' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to eql(1)
        end
      end

      context 'when multiple bindings exist in a space' do
        let!(:service_binding1) { ServiceBinding.make(app: AppModel.make(space: space), service_instance: service_instance) }
        let!(:service_binding2) { ServiceBinding.make(app: AppModel.make(space: space), service_instance: service_instance) }
        let!(:other_service_binding) { ServiceBinding.make }

        it 'returns the bindings for the correct space' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to eql(2)
        end
      end

      context 'when multiple service instances exist' do
        let!(:service_binding) { ServiceBinding.make(app: AppModel.make(space: space), service_instance: service_instance) }
        let!(:other_service_binding) { ServiceBinding.make(service_instance: ServiceInstance.make(space: space)) }

        it 'returns the binding for the correct service instance' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to eql(1)
        end
      end
    end
  end
end
