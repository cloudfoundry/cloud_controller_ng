require 'spec_helper'
require 'messages/orgs_list_message'

module VCAP::CloudController
  RSpec.describe OrgsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'Case,Molly',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'name',
          'guids' => 'one-guid,two-guid,three-guid'
        }
      end

      it 'returns the correct OrgsListMessage' do
        message = OrgsListMessage.from_params(params)

        expect(message).to be_a(OrgsListMessage)

        expect(message).to be_valid
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.names).to eq(%w[Case Molly])
        expect(message.guids).to eq(%w[one-guid two-guid three-guid])
      end

      it 'converts requested keys to symbols' do
        message = OrgsListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:names)
        expect(message).to be_requested(:order_by)
        expect(message).to be_requested(:guids)
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: %w[Case Molly],
          page: 1,
          per_page: 5,
          order_by: 'name',
          guids: ['one-guid,two-guid,three-guid']
        }
      end

      it 'excludes the pagination keys' do
        expected_params = %i[names guids]
        expect(OrgsListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          OrgsListMessage.from_params({
                                        names: [],
                                        page: 1,
                                        per_page: 5
                                      })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = OrgsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = OrgsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = OrgsListMessage.from_params names: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          message = OrgsListMessage.from_params guids: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates that order_by value is in the supported list' do
          message = OrgsListMessage.from_params order_by: 'invalid'
          expect(message).not_to be_valid
          expect(message.errors[:order_by].length).to eq 1
        end

        it 'validates requirements' do
          message = OrgsListMessage.from_params('label_selector' => '')

          expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
            to receive(:validate).
            with(message).
            and_call_original
          message.valid?
        end
      end
    end
  end
end
