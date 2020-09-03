require 'spec_helper'
require 'messages/service_offerings_list_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServiceOfferingsListMessage do
    let(:params) do
      {
        'available' => 'true',
        'service_broker_guids' => 'one,two',
        'service_broker_names' => 'zhou,qin',
        'names' => 'service_offering1,other_2',
        'space_guids' => 'space_1,space_2',
        'organization_guids' => 'organization_1,organization_2',
        'fields' => { 'service_broker' => 'guid,name' }
      }.with_indifferent_access
    end

    describe '.from_params' do
      it 'returns the correct message' do
        message = described_class.from_params(params)

        expect(message).to be_valid
        expect(message).to be_a(described_class)
        expect(message.available).to eq('true')
        expect(message.service_broker_guids).to eq(%w(one two))
        expect(message.service_broker_names).to eq(%w(zhou qin))
        expect(message.names).to eq(%w(service_offering1 other_2))
        expect(message.space_guids).to eq(%w(space_1 space_2))
        expect(message.organization_guids).to eq(%w(organization_1 organization_2))
      end

      it 'converts requested keys to symbols' do
        message = described_class.from_params(params)

        expect(message.requested?(:available)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:service_broker_guids)).to be_truthy
        expect(message.requested?(:service_broker_names)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
      end

      it 'accepts an empty set' do
        message = described_class.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = described_class.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'values for `available`' do
        it 'accepts `true`' do
          message = described_class.from_params({ available: 'true' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.available).to eq('true')
        end

        it 'accepts `false`' do
          message = described_class.from_params({ available: 'false' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.available).to eq('false')
        end

        it 'does not accept other values' do
          message = described_class.from_params({ available: 'nope' }.with_indifferent_access)

          expect(message).not_to be_valid
          expect(message.errors[:available]).to include("only accepts values 'true' or 'false'")
        end
      end

      context 'fields' do
        it_behaves_like 'fields query hash'

        it_behaves_like 'field query parameter', 'service_broker', 'guid,name'
      end
    end

    describe '.to_param_hash' do
      let(:message) { described_class.from_params(params) }

      it_behaves_like 'fields to_param_hash', 'service_broker', 'guid,name'
    end

    describe 'order_by' do
      it 'corrects `name` to `label`' do
        message = described_class.from_params(order_by: 'name')
        expect(message).to be_valid
        expect(message.pagination_options.order_by).to eq('label')
        expect(message.pagination_options.order_direction).to eq('asc')
      end

      it 'corrects `-name` to `label`' do
        message = described_class.from_params(order_by: '-name')
        expect(message).to be_valid
        expect(message.pagination_options.order_by).to eq('label')
        expect(message.pagination_options.order_direction).to eq('desc')
      end
    end
  end
end
