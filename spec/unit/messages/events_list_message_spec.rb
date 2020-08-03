require 'spec_helper'
require 'messages/events_list_message'

module VCAP::CloudController
  RSpec.describe EventsListMessage do
    describe '.from_params' do
      let(:params) do
        {}
      end

      it 'returns the correct EventsListMessage' do
        message = EventsListMessage.from_params(params)

        expect(message).to be_a(EventsListMessage)
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = EventsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a set of fields' do
        message = EventsListMessage.from_params({
          types: ['audit.app.create'],
          target_guids: ['guid1', 'guid2'],
          space_guids: ['guid3', 'guid4'],
          organization_guids: ['guid5', 'guid6'],
          created_ats: { lt: Time.now.utc.iso8601 },
          updated_ats: { gt: Time.now.utc.iso8601 },
        })
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = EventsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'validations' do
        it 'validates the types filter' do
          message = EventsListMessage.from_params({ types: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:types]).to include('must be an array')
        end

        it 'validates the target_guids filter' do
          message = EventsListMessage.from_params({ target_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:target_guids]).to include('must be an array')
        end

        it 'validates the space_guids filter' do
          message = EventsListMessage.from_params({ space_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:space_guids]).to include('must be an array')
        end

        it 'validates the organization_guids filter' do
          message = EventsListMessage.from_params({ organization_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:organization_guids]).to include('must be an array')
        end

        context 'validates the created_ats filter' do
          it 'delegates to the TimestampValidator' do
            message = EventsListMessage.from_params({ created_ats: 47 })
            expect(message).not_to be_valid
            expect(message.errors[:created_ats]).to include('relational operator and timestamp must be specified')
          end
        end

        context 'validates the updated_ats filter' do
          it 'delegates to the TimestampValidator' do
            message = EventsListMessage.from_params({ updated_ats: 47 })
            expect(message).not_to be_valid
            expect(message.errors[:updated_ats]).to include('relational operator and timestamp must be specified')
          end
        end
      end
    end
  end
end
