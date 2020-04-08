require 'spec_helper'
require 'messages/stacks_list_message'

module VCAP::CloudController
  RSpec.describe StacksListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'name1,name2',
          'page' => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct StacksListMessage' do
        message = StacksListMessage.from_params(params)

        expect(message).to be_a(StacksListMessage)
        expect(message.names).to eq(%w(name1 name2))
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = StacksListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: %w(name1 name2),
          page: 1,
          per_page: 5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names]
        expect(StacksListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          StacksListMessage.from_params({
            names: []
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = StacksListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = StacksListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      it 'validates names is an array' do
        message = StacksListMessage.from_params names: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:names].length).to eq 1
      end

      it 'validates label selector' do
        message = StacksListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
