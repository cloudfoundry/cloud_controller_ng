require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  RSpec.describe AppsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names'              => 'name1,name2',
          'guids'              => 'guid1,guid2',
          'organization_guids' => 'orgguid',
          'space_guids'        => 'spaceguid',
          'page'               => 1,
          'per_page'           => 5,
          'order_by'           => 'created_at'
        }
      end

      it 'returns the correct AppsListMessage' do
        message = AppsListMessage.from_params(params)

        expect(message).to be_a(AppsListMessage)
        expect(message.names).to eq(['name1', 'name2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.organization_guids).to eq(['orgguid'])
        expect(message.space_guids).to eq(['spaceguid'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = AppsListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
            names:              ['name1', 'name2'],
            guids:              ['guid1', 'guid2'],
            organization_guids: ['orgguid1', 'orgguid2'],
            space_guids:        ['spaceguid1', 'spaceguid2'],
            page:               1,
            per_page:           5,
            order_by:           'created_at',
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :guids, :organization_guids, :space_guids]
        expect(AppsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppsListMessage.new({
              names:              [],
              guids:              [],
              organization_guids: [],
              space_guids:        [],
              page:               1,
              per_page:           5,
              order_by:           'created_at',
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AppsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = AppsListMessage.new names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          message = AppsListMessage.new guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates organization_guids is an array' do
          message = AppsListMessage.new organization_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          message = AppsListMessage.new space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:space_guids].length).to eq 1
        end
      end
    end
  end
end
