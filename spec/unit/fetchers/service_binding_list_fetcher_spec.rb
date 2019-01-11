require 'spec_helper'
require 'fetchers/service_binding_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceBindingListFetcher do
    let(:fetcher) { ServiceBindingListFetcher.new(message) }
    let(:message) { ServiceBindingsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let(:service_instance_1) { ManagedServiceInstance.make }
      let(:service_instance_2) { ManagedServiceInstance.make }
      let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'includes all the V3 Service Bindings' do
        results = fetcher.fetch_all.all
        expect(results.length).to eq 2
        expect(results).to include(service_binding_1, service_binding_2)
      end

      context 'filter' do
        context 'app_guids' do
          let(:filters) { { app_guids: [service_binding_1.app.guid] } }

          it 'only returns matching service bindings' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([service_binding_1])
            expect(results).not_to include(service_binding_2)
          end
        end

        context 'service_instance_guids' do
          let(:filters) { { service_instance_guids: [service_instance_1.guid] } }

          it 'only returns matching service bindings' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([service_binding_1])
            expect(results).not_to include(service_binding_2)
          end
        end
      end
    end

    describe '#fetch' do
      let(:service_instance_1) { ManagedServiceInstance.make(space: space_1) }
      let(:service_instance_2) { ManagedServiceInstance.make(space: space_2) }

      let!(:service_binding_1) { ServiceBinding.make(app: app_model, service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(app: app_model2, service_instance: service_instance_2) }
      let!(:undesirable_service_binding) { ServiceBinding.make }

      let(:space_1) { Space.make }
      let(:space_2) { Space.make }

      let(:app_model) { AppModel.make(space: space_1) }
      let(:app_model2) { AppModel.make(space: space_2) }

      it 'returns all of the desired service bindings' do
        results = fetcher.fetch(space_guids: [space_1.guid, space_2.guid]).all

        expect(results).to include(service_binding_1, service_binding_2)
        expect(results).not_to include(undesirable_service_binding)
      end

      context 'filter' do
        context 'app_guids' do
          let(:filters) { { app_guids: [app_model.guid] } }

          it 'only returns matching service bindings' do
            results = fetcher.fetch(space_guids: [space_1.guid, space_2.guid]).all
            expect(results).to match_array([service_binding_1])
            expect(results).not_to include(undesirable_service_binding, service_binding_2)
          end
        end

        context 'service_instance_guids' do
          let(:filters) { { service_instance_guids: [service_instance_1.guid] } }

          it 'only returns matching service bindings' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([service_binding_1])
            expect(results).not_to include(service_binding_2)
          end
        end
      end
    end

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
