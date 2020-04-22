require 'spec_helper'
require 'messages/service_plans_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServicePlansShowMessage do
    describe '.from_params' do
      let(:params) do
        {
          'fields' => { 'service_offering.service_broker' => 'guid,name' },
        }.with_indifferent_access
      end

      it 'returns the correct ServicePlansShowMessage' do
        message = described_class.from_params(params)

        expect(message).to be_valid
        expect(message).to be_a(described_class)
        expect(message.fields).to match({ 'service_offering.service_broker': ['guid', 'name'] })
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
        it 'validates `fields` is a hash' do
          message = described_class.from_params({ 'fields' => 'foo' }.with_indifferent_access)
          expect(message).not_to be_valid
          expect(message.errors[:fields][0]).to include('must be an object')
        end

        it_behaves_like 'field query parameter', 'service_offering.service_broker', 'guid,name'

        it 'does not accept fields resources that are not allowed' do
          message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
          expect(message).not_to be_valid
          expect(message.errors[:fields]).to include(
            "[space.foo] valid resources are: 'service_offering.service_broker'"
          )
        end
      end
    end
  end
end
