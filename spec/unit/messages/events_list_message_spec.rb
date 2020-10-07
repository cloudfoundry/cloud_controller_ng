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
          guids: ['event_guid1'],
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
        it 'validates the guids filter' do
          message = EventsListMessage.from_params({ guids: '123,456' })
          expect(message).not_to be_valid
          expect(message.errors[:guids]).to include('must be an array')
        end

        it 'validates the types filter' do
          message = EventsListMessage.from_params({ types: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:types]).to include('must be an array')
        end

        context 'target_guids' do
          it 'does not allow non-array values' do
            message = EventsListMessage.from_params({ target_guids: 'not an array' })
            expect(message).not_to be_valid
            expect(message.errors_on(:target_guids)).to contain_exactly('target_guids must be an array')
          end

          it 'is valid for an array' do
            message = EventsListMessage.from_params({ target_guids: ['guid1', 'guid2'] })
            expect(message).to be_valid
          end

          it 'does not allow random operators' do
            message = EventsListMessage.from_params({ target_guids: { weyman: ['not a number'] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:target_guids)).to contain_exactly('target_guids has an invalid operator')
          end

          it 'allows the not operator' do
            message = EventsListMessage.from_params({ target_guids: { not: ['guid1'] } })
            expect(message).to be_valid
          end

          it 'does not allow non-array values in the "not" field' do
            message = EventsListMessage.from_params({ target_guids: { not: 'not an array' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:target_guids)).to contain_exactly('target_guids must be an array')
          end
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
      end
    end

    context 'exclude target guids' do
      it 'returns false for an array' do
        message = EventsListMessage.from_params({ target_guids: ['an array'] })
        expect(message).to be_valid
        expect(message.exclude_target_guids?).to be false
      end

      it 'returns false for a hash with the wrong key' do
        message = EventsListMessage.from_params({ target_guids: { mona: ['an array'] } })
        expect(message).not_to be_valid
        expect(message.exclude_target_guids?).to be false
      end

      it 'returns true for a hash with the right key' do
        message = EventsListMessage.from_params({ target_guids: { not: ['an array'] } })
        expect(message).to be_valid
        expect(message.exclude_target_guids?).to be true
      end
    end
  end
end
