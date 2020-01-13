require 'spec_helper'
require 'messages/service_offerings_list_message'

module VCAP::CloudController
  RSpec.describe ServiceOfferingsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'available' => 'true',
          'service_broker_guids' => 'one,two',
        }.with_indifferent_access
      end

      it 'returns the correct ServiceOfferingsListMessage' do
        message = ServiceOfferingsListMessage.from_params(params)

        expect(message).to be_a(ServiceOfferingsListMessage)
        expect(message.available).to eq('true')
        expect(message.service_broker_guids).to eq(%w(one two))
      end

      it 'converts requested keys to symbols' do
        message = ServiceOfferingsListMessage.from_params(params)

        expect(message.requested?(:available)).to be_truthy
      end
    end

    describe 'validation' do
      it 'accepts an empty set' do
        message = ServiceOfferingsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts defined fields' do
        message = ServiceOfferingsListMessage.from_params({
          available: 'false',
          service_broker_guids: 'one,two',
        }.with_indifferent_access)
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = ServiceOfferingsListMessage.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'values for `available`' do
        it 'accepts `true`' do
          message = ServiceOfferingsListMessage.from_params({ available: 'true' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.available).to eq('true')
        end

        it 'accepts `false`' do
          message = ServiceOfferingsListMessage.from_params({ available: 'false' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.available).to eq('false')
        end

        it 'does not accept other values' do
          message = ServiceOfferingsListMessage.from_params({ available: 'nope' }.with_indifferent_access)

          expect(message).not_to be_valid
          expect(message.errors[:available]).to include("only accepts values 'true' or 'false'")
        end
      end
    end
  end
end
