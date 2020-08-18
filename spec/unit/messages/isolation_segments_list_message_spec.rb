require 'spec_helper'
require 'messages/isolation_segments_list_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names'              => 'name1,name2',
          'guids'              => 'guid1,guid2',
          'organization_guids' => 'o-guid1,o-guid2',
          'label_selector'     => 'foo=bar',
          'page'               => 1,
          'per_page'           => 5,
          'order_by'           => 'created_at',
          'created_ats'        => "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          'updated_ats'        => { gt: Time.now.utc.iso8601 }
        }
      end

      it 'returns the correct IsolationSegmentsListMessage' do
        message = IsolationSegmentsListMessage.from_params(params)

        expect(message).to be_a(IsolationSegmentsListMessage)
        expect(message.names).to eq(['name1', 'name2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.organization_guids).to eq(['o-guid1', 'o-guid2'])
        expect(message.label_selector).to eq('foo=bar')
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = IsolationSegmentsListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:label_selector)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:created_ats)).to be_truthy
        expect(message.requested?(:updated_ats)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
            names:              ['name1', 'name2'],
            guids:              ['guid1', 'guid2'],
            organization_guids:  ['o-guid1', 'o-guid2'],
            label_selector:     'foo=bar',
            page:               1,
            per_page:           5,
            order_by:           'created_at',
            created_ats:        [Time.now.utc.iso8601, Time.now.utc.iso8601],
            updated_ats:        { gt: Time.now.utc.iso8601 }
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [
          :names,
          :guids,
          :organization_guids,
          :label_selector,
          :created_ats,
          :updated_ats,
        ]
        expect(IsolationSegmentsListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          IsolationSegmentsListMessage.from_params({
              names:              [],
              guids:              [],
              organization_guids: [],
              label_selector:     '',
              page:               1,
              per_page:           5,
              order_by:           'created_at',
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = IsolationSegmentsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = IsolationSegmentsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'order_by' do
        it 'allows name' do
          message = IsolationSegmentsListMessage.from_params(order_by: 'name')
          expect(message).to be_valid
        end
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = IsolationSegmentsListMessage.from_params names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          message = IsolationSegmentsListMessage.from_params guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates requirements' do
          message = IsolationSegmentsListMessage.from_params('label_selector' => '')

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
