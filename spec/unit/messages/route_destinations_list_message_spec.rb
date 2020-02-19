require 'spec_helper'
require 'messages/route_destinations_list_message'

module VCAP::CloudController
  RSpec.describe RouteDestinationsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'guids' => 'guid1,guid2',
          'app_guids' => 'guid3,guid4'
        }
      end

      it 'returns the correct RouteDestinationsListMessage' do
        message = RouteDestinationsListMessage.from_params(params)

        expect(message).to be_a(RouteDestinationsListMessage)
        expect(message.guids).to match_array(['guid1', 'guid2'])
        expect(message.app_guids).to match_array(['guid3', 'guid4'])
      end

      it 'converts requested keys to symbols' do
        message = RouteDestinationsListMessage.from_params(params)

        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = RouteDestinationsListMessage.from_params({
          guids:   'some-guid,other-guid',
          app_guids: 'guid-a,guid-b'
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = RouteDestinationsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = RouteDestinationsListMessage.from_params(foobar: 'pants')

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
