require 'spec_helper'
require 'messages/orgs/orgs_list_message'

module VCAP::CloudController
  RSpec.describe OrgsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'Case,Molly',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'name',
        }
      end

      it 'returns the correct OrgsListMessage' do
        message = OrgsListMessage.from_params(params)

        expect(message).to be_a(OrgsListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.names).to eq(['Case', 'Molly'])
        expect(message).to be_valid
      end

      it 'converts requested keys to symbols' do
        message = OrgsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: ['Case', 'Molly'],
          page: 1,
          per_page: 5,
          order_by: 'name',
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names]
        expect(OrgsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          OrgsListMessage.new({
            names: [],
            page: 1,
            per_page: 5,
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = OrgsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = OrgsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = OrgsListMessage.new names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates that order_by value is in the supported list' do
          message = OrgsListMessage.new order_by: 'invalid'
          expect(message).to be_invalid
          expect(message.errors[:order_by].length).to eq 1
        end
      end
    end
  end
end
