require 'db_spec_helper'
require 'fetchers/service_binding_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceBindingListFetcher do
    let(:fetcher) { ServiceBindingListFetcher }

    describe '#fetch_service_instance_bindings_in_space' do
      let(:space) { create(:space) }
      let(:service_instance) { create(:service_instance, space:) }

      it 'returns a Sequel::Dataset' do
        results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
        expect(results).to be_a(Sequel::Dataset)
      end

      context 'when there are no bindings' do
        it 'returns an empty dataset' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to be(0)
        end
      end

      context 'when a binding exists in a space' do
        let!(:service_binding) { create(:service_binding, app: create(:app_model, space:), service_instance: service_instance) }
        let!(:other_service_binding) { create(:service_binding) }

        it 'returns the binding for the correct space' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to be(1)
        end
      end

      context 'when multiple bindings exist in a space' do
        let!(:service_binding1) { create(:service_binding, app: create(:app_model, space:), service_instance: service_instance) }
        let!(:service_binding2) { create(:service_binding, app: create(:app_model, space:), service_instance: service_instance) }
        let!(:other_service_binding) { create(:service_binding) }

        it 'returns the bindings for the correct space' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to be(2)
        end
      end

      context 'when multiple service instances exist' do
        let!(:service_binding) { create(:service_binding, app: create(:app_model, space:), service_instance: service_instance) }
        let!(:other_service_binding) { create(:service_binding, service_instance: create(:service_instance, space:)) }

        it 'returns the binding for the correct service instance' do
          results = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(service_instance.guid, space.guid)
          expect(results.count).to be(1)
        end
      end
    end
  end
end
