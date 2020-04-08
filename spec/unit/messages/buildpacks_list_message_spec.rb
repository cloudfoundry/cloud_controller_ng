require 'spec_helper'
require 'messages/buildpacks_list_message'

module VCAP::CloudController
  RSpec.describe BuildpacksListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'name1,name2',
          'stacks' => 'stack1,stack2',
          'label_selector' => 'foo=bar',
          'page' => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct BuildpacksListMessage' do
        message = BuildpacksListMessage.from_params(params)

        expect(message).to be_a(BuildpacksListMessage)

        expect(message.stacks).to eq(%w(stack1 stack2))
        expect(message.names).to eq(%w(name1 name2))
        expect(message.label_selector).to eq('foo=bar')
        expect(message.requirements.first.key).to eq('foo')
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = BuildpacksListMessage.from_params(params)

        expect(message.requested?(:stacks)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:label_selector)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: %w(name1 name2),
          stacks: %w(stack1 stack2),
          label_selector:     'foo=bar',
          page: 1,
          per_page: 5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :stacks, :label_selector]
        expect(BuildpacksListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          BuildpacksListMessage.from_params({
            names: [],
            stacks: [],
            label_selector:     '',
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = BuildpacksListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = BuildpacksListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      it 'validates names is an array' do
        message = BuildpacksListMessage.from_params names: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:names].length).to eq 1
      end

      it 'validates stacks is an array' do
        message = BuildpacksListMessage.from_params stacks: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:stacks].length).to eq 1
      end

      it 'validates requirements' do
        message = BuildpacksListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
