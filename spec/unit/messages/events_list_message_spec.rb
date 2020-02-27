require 'spec_helper'
require 'messages/events_list_message'

module VCAP::CloudController
  RSpec.describe EventsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'types' => 'audit.app.create',
          'target_guids' => 'guid1,guid2',
          'space_guids' => 'guid3,guid4',
          'organization_guids' => 'guid5,guid6',
        }
      end

      it 'returns the correct EventsListMessage' do
        message = EventsListMessage.from_params(params)

        expect(message).to be_a(EventsListMessage)
        expect(message.types).to eq(['audit.app.create'])
        expect(message.target_guids).to eq(['guid1', 'guid2'])
        expect(message.space_guids).to eq(['guid3', 'guid4'])
        expect(message.organization_guids).to eq(['guid5', 'guid6'])
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = EventsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a set of fields' do
        message = EventsListMessage.from_params({
          'types' => 'audit.app.create',
          'target_guids' => 'guid1,guid2',
          'space_guids' => 'guid3,guid4',
          'organization_guids' => 'guid5,guid6',
        })
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = EventsListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
