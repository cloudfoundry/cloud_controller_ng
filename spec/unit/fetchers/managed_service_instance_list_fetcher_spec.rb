require 'spec_helper'
require 'fetchers/managed_service_instance_list_fetcher'
require 'messages/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ManagedServiceInstanceListFetcher do
    let(:filters) { {} }
    let(:message) { ServiceInstancesListMessage.from_params(filters) }
    let(:fetcher) { ManagedServiceInstanceListFetcher.new }

    describe '#fetch_all' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq', space: FactoryBot.create(:space, guid: 'space-1')) }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis', space: FactoryBot.create(:space, guid: 'space-2')) }
      let!(:service_instance_3) { ManagedServiceInstance.make(name: 'mysql', space: FactoryBot.create(:space, guid: 'space-3')) }
      let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(name: 'my-thing') }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message: message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'includes only the managed service instances' do
        results = fetcher.fetch_all(message: message).all
        expect(results.length).to eq 3
        expect(results).to include(service_instance_1, service_instance_2, service_instance_3)
      end

      context 'filter' do
        context 'by service instance name' do
          let(:filters) { { names: ['rabbitmq', 'redis'] } }

          it 'only returns matching managed service instances' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_1, service_instance_2])
            expect(results).not_to include(service_instance_3)
          end
        end

        context 'by space guid' do
          let(:filters) { { space_guids: ['space-2', 'space-3'] } }

          it 'only returns matching service instances' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_2, service_instance_3])
            expect(results).not_to include(service_instance_1)
          end

          context 'when the space contains no service instances' do
            let(:space) { FactoryBot.create(:space, guid: 'space-guid') }
            let(:filters) { { space_guids: ['space-guid'] } }

            it 'returns an empty list' do
              results = fetcher.fetch_all(message: message).all
              expect(results).to be_empty
            end
          end

          context 'when filtering by an empty list of space guids' do
            let(:filters) { { space_guids: [] } }

            it 'returns an empty list' do
              results = fetcher.fetch_all(message: message).all
              expect(results).to be_empty
            end
          end

          context 'when filtering by a non-existent space guid' do
            let(:filters) { { space_guids: ['nonexistent-space-guid'] } }

            it 'returns an empty list' do
              results = fetcher.fetch_all(message: message).all
              expect(results).to be_empty
            end
          end
        end

        context 'by all query params' do
          let!(:service_instance_4) { ManagedServiceInstance.make(name: 'couchdb', space: service_instance_3.space) }
          let(:filters) {
            {
              space_guids: ['space-3'],
              names: ['couchdb'],
            }
          }

          it 'only returns matching service instances' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_4])
          end
        end

        context 'filtering label selectors' do
          let(:filters) { { 'label_selector' => 'key=value' } }
          let!(:label) { ServiceInstanceLabelModel.make(resource_guid: service_instance_3.guid, key_name: 'key', value: 'value') }

          it 'returns the correct set of service instances' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_3])
          end
        end
      end
    end

    describe '#fetch' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq', space: space_1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis', space: space_1) }
      let!(:service_instance_3) { ManagedServiceInstance.make(name: 'mysql', space: space_2) }
      let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(name: 'my-thing', space: space_1) }

      let(:space_1) { FactoryBot.create(:space, guid: 'space-1') }
      let(:space_2) { FactoryBot.create(:space, guid: 'space-2') }

      it 'returns only the managed service instances in the specified space' do
        results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all

        expect(results).to match_array([service_instance_1, service_instance_2])
      end

      context 'filter' do
        context 'by service instance name' do
          let(:filters) { { names: ['rabbitmq'] } }

          it 'only returns matching service instances' do
            results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
            expect(results).to match_array([service_instance_1])
          end
        end

        context 'by space guid' do
          let(:filters) { { space_guids: ['space-1'] } }

          it 'only returns matching service instances' do
            results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
            expect(results).to match_array([service_instance_1, service_instance_2])
            expect(results).not_to include(service_instance_3)
          end

          context 'when the space contains no service instances' do
            let(:space) { FactoryBot.create(:space, guid: 'space-guid') }
            let(:filters) { { space_guids: ['space-guid'] } }

            it 'returns an empty list' do
              results = fetcher.fetch(message: message, readable_space_guids: [space.guid]).all
              expect(results).to be_empty
            end
          end

          context 'when filtering by an empty list of space guids' do
            let(:filters) { { space_guids: [] } }

            it 'returns an empty list' do
              results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
              expect(results).to be_empty
            end
          end

          context 'when filtering by a non-existent space guid' do
            let(:filters) { { space_guids: ['nonexistent-space-guid'] } }

            it 'returns an empty list' do
              results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
              expect(results).to be_empty
            end
          end
        end

        context 'by all query params' do
          let(:filters) {
            {
              space_guids: ['space-1'],
              names: ['rabbitmq'],
            }
          }

          it 'only returns matching managed service instances' do
            results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
            expect(results).to match_array([service_instance_1])
          end
        end

        context 'by non-existent service instance name' do
          let(:filters) { { names: ['made-up-name'] } }

          it 'returns no matching service instances' do
            results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
            expect(results).to be_empty
          end
        end

        context 'by non-existent space guid' do
          let(:filters) { { space_guids: ['made-up-name'] } }

          it 'returns no matching service instances' do
            results = fetcher.fetch(message: message, readable_space_guids: [space_1.guid]).all
            expect(results).to be_empty
          end
        end
      end

      context 'when managed service instances are shared' do
        let(:shared_to_space) { FactoryBot.create(:space) }

        before do
          service_instance_2.add_shared_space(shared_to_space)
          service_instance_1.add_shared_space(shared_to_space)
        end

        it 'returns all of the service instances shared into the specified space' do
          results = fetcher.fetch(message: message, readable_space_guids: [shared_to_space.guid]).all
          expect(results).to match_array([service_instance_1, service_instance_2])
        end
      end

      context 'when a space contains both shared and non-shared service instances' do
        let(:shared_to_space) { FactoryBot.create(:space) }
        let!(:service_instance_4) { ManagedServiceInstance.make(space: shared_to_space) }

        before do
          service_instance_2.add_shared_space(shared_to_space)
          service_instance_1.add_shared_space(shared_to_space)
        end

        it 'returns all of the service instances shared into the specified space' do
          results = fetcher.fetch(message: message, readable_space_guids: [shared_to_space.guid]).all
          expect(results).to match_array([service_instance_1, service_instance_2, service_instance_4])
        end
      end
    end
  end
end
