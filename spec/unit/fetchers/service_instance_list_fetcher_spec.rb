require 'spec_helper'
require 'fetchers/service_instance_list_fetcher'
require 'messages/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceListFetcher do
    let(:filters) { {} }
    let(:message) { ServiceInstancesListMessage.from_params(filters) }
    let(:fetcher) { described_class.new }

    describe '#fetch' do
      let(:space_1) { Space.make }
      let(:space_2) { Space.make }
      let(:space_3) { Space.make }
      let!(:msi_1) { ManagedServiceInstance.make(space: space_1) }
      let!(:msi_2) { ManagedServiceInstance.make(space: space_2) }
      let!(:msi_3) { ManagedServiceInstance.make(space: space_3) }
      let!(:upsi) { UserProvidedServiceInstance.make(space: space_1) }
      let!(:ssi) { ManagedServiceInstance.make(space: space_3) }

      before do
        ssi.add_shared_space(space_2)
      end

      it 'fetches everything for omniscient users' do
        expect(fetcher.fetch(message, omniscient: true).all).to contain_exactly(msi_1, msi_2, msi_3, upsi, ssi)
      end

      it 'fetches nothing for users who cannot see any spaces' do
        expect(fetcher.fetch(message).all).to be_empty
      end

      it 'fetches the instances owned by readable spaces' do
        dataset = fetcher.fetch(message, readable_space_guids: [space_1.guid, space_3.guid])
        expect(dataset.all).to contain_exactly(msi_1, msi_3, upsi, ssi)
      end

      it 'fetches the instances shared to readable spaces' do
        dataset = fetcher.fetch(message, readable_space_guids: [space_2.guid])
        expect(dataset.all).to contain_exactly(msi_2, ssi)
      end

      context 'filtering' do
        context 'by names' do
          let(:filters) { { names: [msi_1.name, ssi.name, 'no-such-name'] } }

          it 'returns instances with matching name' do
            expect(fetcher.fetch(message, omniscient: true)).to contain_exactly(msi_1, ssi)
            expect(fetcher.fetch(message, readable_space_guids: [space_1.guid])).to contain_exactly(msi_1)
          end
        end
      end

      context 'by space_guids' do
        let(:filters) { { space_guids: [space_1.guid, 'no-such-space-guid'] } }

        it 'returns instances with matching space guids' do
          expect(fetcher.fetch(message, omniscient: true)).to contain_exactly(msi_1, upsi)
          expect(fetcher.fetch(message, readable_space_guids: [space_1.guid, space_2.guid])).to contain_exactly(msi_1, upsi)
        end
      end

      context 'by label selector' do
        let(:filters) { { 'label_selector' => 'key=value' } }
        before do
          ServiceInstanceLabelModel.make(resource_guid: msi_2.guid, key_name: 'key', value: 'value')
        end

        it 'returns instances with matching labels' do
          expect(fetcher.fetch(message, omniscient: true)).to contain_exactly(msi_2)
          expect(fetcher.fetch(message, readable_space_guids: [space_1.guid, space_2.guid])).to contain_exactly(msi_2)
        end
      end
    end
  end
end
