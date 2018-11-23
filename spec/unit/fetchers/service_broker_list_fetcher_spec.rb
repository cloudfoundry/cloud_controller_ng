require 'spec_helper'
require 'fetchers/service_broker_list_fetcher'
require 'messages/service_brokers_list_message'

module VCAP::CloudController
  RSpec.describe ServiceBrokerListFetcher do
    describe '#fetch' do
      let(:broker) { ServiceBroker.make }

      let(:space_1) { Space.make }
      let(:space_scoped_broker_1) { ServiceBroker.make(space_guid: space_1.guid) }

      let(:space_2) { Space.make }
      let(:space_scoped_broker_2) { ServiceBroker.make(space_guid: space_2.guid) }

      let(:fetcher) { ServiceBrokerListFetcher.new }
      let(:message) { ServiceBrokersListMessage.from_params(filters) }

      let(:brokers) { fetcher.fetch(message).all }

      before do
        broker.save
        space_scoped_broker_1.save
        space_scoped_broker_2.save

        expect(message).to be_valid
      end

      context 'when no filters are provided' do
        let(:filters) { {} }

        it 'includes all the brokers' do
          expect(brokers).to contain_exactly(
            broker, space_scoped_broker_1, space_scoped_broker_2
          )
        end
      end

      context 'when filtering by space GUIDs' do
        let(:filters) { { space_guids: [space_1.guid] } }

        it 'includes the relevant brokers' do
          expect(brokers).to contain_exactly(space_scoped_broker_1)
        end
      end

      context 'when a list of permitted space_guids is provided' do
        let(:permitted_space_guids) { [space_1.guid, space_2.guid] }
        let(:brokers) { fetcher.fetch(message, permitted_space_guids).all }

        context 'when no filters are provided' do
          let(:filters) { {} }

          it 'includes only the brokers in the permitted spaces' do
            expect(brokers).to contain_exactly(
              space_scoped_broker_1, space_scoped_broker_2
            )
          end
        end
      end
    end
  end
end
