require 'spec_helper'
require 'fetchers/service_broker_list_fetcher'
require 'messages/service_brokers_list_message'

module VCAP::CloudController
  RSpec.describe ServiceBrokerListFetcher do
    describe '#fetch' do
      let(:broker) { ServiceBroker.make }

      let(:space_1) { Space.make }
      let(:space_scoped_broker_1) { ServiceBroker.make(space_guid: space_1.guid, name: 'broker-1') }

      let(:space_2) { Space.make }
      let(:space_scoped_broker_2) { ServiceBroker.make(space_guid: space_2.guid, name: 'broker-2') }

      let(:space_3) { Space.make }
      let(:space_scoped_broker_3) { ServiceBroker.make(space_guid: space_3.guid, name: 'broker-3') }

      let(:fetcher) { ServiceBrokerListFetcher.new }
      let(:message) { ServiceBrokersListMessage.from_params(filters) }

      before do
        broker.save
        space_scoped_broker_1.save
        space_scoped_broker_2.save
        space_scoped_broker_3.save

        expect(message).to be_valid
      end

      context 'when no filters are provided' do
        let(:filters) { {} }

        it 'includes all the brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to contain_exactly(
            broker, space_scoped_broker_1, space_scoped_broker_2, space_scoped_broker_3
          )
        end
      end

      context 'when filtering by space GUIDs' do
        let(:filters) { { space_guids: [space_1.guid, space_2.guid] } }

        it 'includes the relevant brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to contain_exactly(space_scoped_broker_1, space_scoped_broker_2)
        end
      end

      context 'when filtering by invalid space GUIDs' do
        let(:filters) { { space_guids: ['invalid-space-guid'] } }

        it 'includes no brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to be_empty
        end
      end

      context 'when filtering by names' do
        let(:filters) { { names: [space_scoped_broker_1.name, space_scoped_broker_3.name] } }

        it 'includes the relevant brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to contain_exactly(space_scoped_broker_1, space_scoped_broker_3)
        end
      end

      context 'when filtering by space guid and names' do
        let(:filters) { {  space_guids: [space_1.guid, space_2.guid],
                           names: [space_scoped_broker_1.name, space_scoped_broker_3.name] }
        }

        it 'includes the relevant brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to contain_exactly(space_scoped_broker_1)
        end
      end

      context 'when filtering by space guid and invalid name' do
        let(:filters) { {  space_guids: [space_1.guid, space_2.guid],
                           names: ['invalid-name'] }
        }

        it 'includes the relevant brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to be_empty
        end
      end

      context 'when filtering by invalid space guid and names' do
        let(:filters) { {  space_guids: ['invalid-space-1'],
                           names: [space_scoped_broker_1.name, space_scoped_broker_3.name] }
        }

        it 'includes the relevant brokers' do
          brokers = fetcher.fetch(message: message).all

          expect(brokers).to be_empty
        end
      end

      context 'when a list of permitted space_guids is provided' do
        let(:permitted_space_guids) { [space_1.guid, space_2.guid] }

        context 'when no filters are provided' do
          let(:filters) { {} }

          it 'includes only the brokers in the permitted spaces' do
            brokers = fetcher.fetch(message: message, permitted_space_guids: permitted_space_guids).all

            expect(brokers).to contain_exactly(
              space_scoped_broker_1, space_scoped_broker_2
            )
          end
        end

        context 'when space guid filter is provided' do
          let(:permitted_space_guids) { [space_1.guid] }
          let(:filters) { { space_guids: [space_1.guid, space_2.guid] } }

          it 'includes only the brokers in the permitted spaces' do
            brokers = fetcher.fetch(message: message, permitted_space_guids: permitted_space_guids).all

            expect(brokers).to contain_exactly(
              space_scoped_broker_1
            )
          end
        end

        context 'when space guid filter is something thats not permitted' do
          let(:permitted_space_guids) { [space_1.guid] }
          let(:filters) { { space_guids: [space_2.guid] } }

          it 'includes no brokers' do
            brokers = fetcher.fetch(message: message, permitted_space_guids: permitted_space_guids).all

            expect(brokers).to be_empty
          end
        end
      end
    end
  end
end
