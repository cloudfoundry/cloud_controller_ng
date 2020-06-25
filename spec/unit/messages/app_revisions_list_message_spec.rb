require 'spec_helper'
require 'messages/app_revisions_list_message'

module VCAP::CloudController
  RSpec.describe AppRevisionsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'versions' => '1,3',
          'page'     => 1,
          'per_page' => 5,
          'label_selector' => 'key=value',
          'deployable' => true
        }
      end

      it 'returns the correct AppRevisionsListMessage' do
        message = AppRevisionsListMessage.from_params(params)

        expect(message).to be_a(AppRevisionsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.versions).to eq(['1', '3'])
        expect(message.deployable).to eq(true)
        expect(message.label_selector).to eq('key=value')
      end

      it 'converts requested keys to symbols' do
        message = AppRevisionsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:versions)).to be_truthy
        expect(message.requested?(:deployable)).to be_truthy
        expect(message.requested?(:label_selector)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          versions: ['1', '3'],
          label_selector:     'key=value',
          page:               1,
          per_page:           5,
          deployable: true,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:versions, :label_selector, :deployable]
        expect(AppRevisionsListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppRevisionsListMessage.from_params({
            page:               1,
            per_page:           5,
            versions:           ['1'],
            deployable:         true,
            label_selector:     'key=value',
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppRevisionsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AppRevisionsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'versions' do
        it 'validates versions to be an array' do
          message = AppRevisionsListMessage.from_params(versions: 'not array at all')
          expect(message).to be_invalid
          expect(message.errors[:versions]).to include('must be an array')
        end

        it 'allows versions to be nil' do
          message = AppRevisionsListMessage.from_params(versions: nil)
          expect(message).to be_valid
        end
      end

      context 'deployable' do
        it 'validates deployable to be a boolean' do
          message = AppRevisionsListMessage.from_params(deployable: 'not a boolean')
          expect(message).to be_invalid
          expect(message.errors[:deployable]).to include('must be a boolean')
        end

        it 'allows deployable to be nil' do
          message = AppRevisionsListMessage.from_params(deployable: nil)
          expect(message).to be_valid
        end
      end

      it 'validates metadata requirements' do
        message = AppRevisionsListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
