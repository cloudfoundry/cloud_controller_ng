require 'spec_helper'
require 'fetchers/service_instance_list_fetcher'
require 'messages/service_instances/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceListFetcher do
    let(:filters) { {} }
    let(:message) { ServiceInstancesListMessage.new(filters) }
    let(:fetcher) { ServiceInstanceListFetcher.new }

    describe '#fetch_all' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq', space: Space.make(guid: 'space-1')) }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis', space: Space.make(guid: 'space-2')) }
      let!(:service_instance_3) { ManagedServiceInstance.make(name: 'mysql', space: Space.make(guid: 'space-3')) }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message: message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'includes all the V3 Service Instances' do
        results = fetcher.fetch_all(message: message).all
        expect(results.length).to eq 3
        expect(results).to include(service_instance_1, service_instance_2, service_instance_3)
      end

      context 'filter' do
        context 'by service instance name' do
          let(:filters) { { names: ['rabbitmq', 'redis'] } }

          it 'only returns matching service instances' do
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
      end
    end

    describe '#fetch' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq', space: space_1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis', space: space_1) }
      let!(:service_instance_3) { ManagedServiceInstance.make(name: 'mysql', space: space_2) }

      let(:space_1) { Space.make(guid: 'space-1') }
      let(:space_2) { Space.make(guid: 'space-2') }

      it 'returns all of the service instances in the specified space' do
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
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_1, service_instance_2])
            expect(results).not_to include(service_instance_3)
          end
        end

        context 'by all query params' do
          let(:filters) {
            {
              space_guids: ['space-1'],
              names: ['rabbitmq'],
            }
          }

          it 'only returns matching service instances' do
            results = fetcher.fetch_all(message: message).all
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

      context 'when service instances are shared' do
        let(:shared_to_space) { Space.make }

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
        let(:shared_to_space) { Space.make }
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
