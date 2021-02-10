require 'spec_helper'
require 'messages/service_offerings_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServiceOfferingsShowMessage do
    describe '.from_params' do
      let(:params) do
        {
          'fields' => { 'service_broker' => 'guid,name' },
        }.with_indifferent_access
      end

      it 'returns the correct message' do
        message = described_class.from_params(params)

        expect(message).to be_valid
        expect(message).to be_a(described_class)
        expect(message.fields).to match({ service_broker: ['guid', 'name'] })
      end

      it 'converts requested keys to symbols' do
        message = described_class.from_params(params)
        expect(message.requested?(:fields)).to be_truthy
      end

      it 'accepts an empty set' do
        message = described_class.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept arbitrary parameters' do
        message = described_class.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'fields' do
        it_behaves_like 'fields query hash'

        it_behaves_like 'field query parameter', 'service_broker', 'guid,name'
      end
    end
  end
end
