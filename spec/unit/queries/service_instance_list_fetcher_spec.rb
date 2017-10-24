require 'spec_helper'
require 'fetchers/service_instance_list_fetcher'
require 'messages/service_instances/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceListFetcher do
    let(:filters) { {} }
    let(:message) { ServiceInstancesListMessage.new(filters) }
    let(:fetcher) { ServiceInstanceListFetcher.new }

    describe '#fetch_all' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq') }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis') }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message: message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'includes all the V3 Service Instances' do
        results = fetcher.fetch_all(message: message).all
        expect(results.length).to eq 2
        expect(results).to include(service_instance_1, service_instance_2)
      end

      context 'filter' do
        context 'by service instance name' do
          let(:filters) { { names: ['rabbitmq'] } }

          it 'only returns matching service instances' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([service_instance_1])
            expect(results).not_to include(service_instance_2)
          end
        end
      end
    end

    describe '#fetch' do
      let!(:service_instance_1) { ManagedServiceInstance.make(name: 'rabbitmq', space: space_1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(name: 'redis', space: space_1) }
      let!(:service_instance_3) { ManagedServiceInstance.make(name: 'mysql', space: space_2) }

      let(:space_1) { Space.make }
      let(:space_2) { Space.make }

      it 'returns all of the service instances in the specified space' do
        results = fetcher.fetch(message: message, space_guids: [space_1.guid]).all

        expect(results).to match_array([service_instance_1, service_instance_2])
      end

      context 'filter' do
        context 'by service instance name' do
          let(:filters) { { names: ['rabbitmq', 'redis'] } }

          it 'only returns matching service instances' do
            results = fetcher.fetch(message: message, space_guids: [space_1.guid]).all
            expect(results).to match_array([service_instance_1, service_instance_2])
          end
        end

        context 'by non-existent service instance name' do
          let(:filters) { { names: ['made-up-name'] } }

          it 'returns no matching service instances' do
            results = fetcher.fetch(message: message, space_guids: [space_1.guid]).all
            expect(results).to be_empty
          end
        end
      end
    end
  end
end
