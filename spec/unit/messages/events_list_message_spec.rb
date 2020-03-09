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
          'created_ats' => '2020-02-24T18:14:40Z,2020-02-25T22:03:05Z',
        }
      end

      it 'returns the correct EventsListMessage' do
        message = EventsListMessage.from_params(params)

        expect(message).to be_a(EventsListMessage)
        expect(message.types).to eq(['audit.app.create'])
        expect(message.target_guids).to eq(['guid1', 'guid2'])
        expect(message.space_guids).to eq(['guid3', 'guid4'])
        expect(message.organization_guids).to eq(['guid5', 'guid6'])
        expect(message.created_ats).to eq(['2020-02-24T18:14:40Z', '2020-02-25T22:03:05Z'])
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
          'created_ats' => '2020-02-24T18:14:40Z,2020-02-25T22:03:05Z',
        })
        expect(message).to be_valid
      end

      it 'accepts fields with greater-than operator' do
        message = EventsListMessage.from_params({
          'created_ats' => {
            'gt' => '2020-02-24T18:14:40Z'
          },
        })
        expect(message).to be_valid
        expect(message.created_ats).to eq(['2020-02-24T18:14:40Z'])
        expect(message.gt_params).to eq(['created_ats'])
      end

      it 'accepts fields with greater-than operator' do
        message = EventsListMessage.from_params({
          'created_ats' => {
            'lt' => '2020-02-24T18:14:40Z'
          },
        })
        expect(message).to be_valid
        expect(message.created_ats).to eq(['2020-02-24T18:14:40Z'])
        expect(message.lt_params).to eq(['created_ats'])
      end

      it 'does not accept a field not in this set' do
        message = EventsListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
