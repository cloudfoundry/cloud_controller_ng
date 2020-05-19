require 'spec_helper'
require 'messages/service_plans_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServicePlansShowMessage do
    describe '.from_params' do
      let(:params) do
        {
          'fields' => { 'service_offering.service_broker' => 'guid,name' },
          'include' => 'space.organization,service_offering',
        }.with_indifferent_access
      end

      it 'returns the correct ServicePlansShowMessage' do
        message = described_class.from_params(params)

        expect(message).to be_valid
        expect(message).to be_a(described_class)
        expect(message.fields).to match({ 'service_offering.service_broker': ['guid', 'name'] })
        expect(message.include).to contain_exactly('space.organization', 'service_offering')
      end

      it 'converts requested keys to symbols' do
        message = described_class.from_params(params)
        expect(message.requested?(:fields)).to be_truthy
        expect(message.requested?(:include)).to be_truthy
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

        it_behaves_like 'field query parameter', 'service_offering.service_broker', 'guid,name'
      end

      context 'include' do
        it 'does not accept other values' do
          message = described_class.from_params({ include: 'space' }.with_indifferent_access)
          expect(message).not_to be_valid
          expect(message.errors[:base]).to include(include("Invalid included resource: 'space'"))
        end
      end
    end
  end
end
