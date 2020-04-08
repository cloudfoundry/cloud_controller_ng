require 'spec_helper'
require 'messages/app_builds_list_message'

module VCAP::CloudController
  RSpec.describe AppBuildsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states'    => 'state1,state2',
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
        }
      end

      it 'returns the correct AppBuildsListMessage' do
        message = AppBuildsListMessage.from_params(params)

        expect(message).to be_a(AppBuildsListMessage)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = AppBuildsListMessage.from_params(params)

        expect(message.requested?(:states)).to be true
        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = AppBuildsListMessage.from_params({
          states:    [],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = AppBuildsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AppBuildsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'reject an invalid order_by field' do
        message = AppBuildsListMessage.from_params({
          order_by:  'fail!',
        })
        expect(message).not_to be_valid
      end

      describe 'validations' do
        context 'when the request contains space_guids' do
          it 'is invalid' do
            message = AppBuildsListMessage.from_params({ space_guids: ['app1', 'app2'] })
            expect(message).to_not be_valid
            expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'space_guids'")
          end
        end

        context 'when the request contains organization_guids' do
          it 'is invalid' do
            message = AppBuildsListMessage.from_params({ organization_guids: ['app1', 'app2'] })
            expect(message).to_not be_valid
            expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'organization_guids'")
          end
        end

        it 'validates states is an array' do
          message = AppBuildsListMessage.from_params states: 'not array at all'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end
      end
    end
  end
end
