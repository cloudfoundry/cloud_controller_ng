require 'spec_helper'
require 'messages/access_rules_list_message'

module VCAP::CloudController
  RSpec.describe AccessRulesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'route_guids' => 'route1,route2',
          'space_guids' => 'space1,space2',
          'names' => 'name1,name2',
          'selectors' => 'selector1,selector2',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'include' => 'selector_resource,route'
        }
      end

      it 'returns the correct AccessRulesListMessage' do
        message = AccessRulesListMessage.from_params(params)

        expect(message).to be_a(AccessRulesListMessage)
        expect(message.route_guids).to eq(%w[route1 route2])
        expect(message.space_guids).to eq(%w[space1 space2])
        expect(message.names).to eq(%w[name1 name2])
        expect(message.selectors).to eq(%w[selector1 selector2])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.include).to eq(%w[selector_resource route])
      end

      it 'converts requested keys to symbols' do
        message = AccessRulesListMessage.from_params(params)

        expect(message).to be_requested(:route_guids)
        expect(message).to be_requested(:space_guids)
        expect(message).to be_requested(:names)
        expect(message).to be_requested(:selectors)
        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:order_by)
        expect(message).to be_requested(:include)
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          route_guids: %w[route1 route2],
          space_guids: %w[space1 space2],
          names: %w[name1 name2],
          selectors: %w[selector1 selector2],
          page: 1,
          per_page: 5,
          order_by: 'created_at',
          include: %w[selector_resource route]
        }
      end

      it 'excludes the pagination keys' do
        expected_params = %i[route_guids space_guids names selectors include]
        expect(AccessRulesListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          AccessRulesListMessage.from_params({
                                               route_guids: [],
                                               space_guids: [],
                                               names: [],
                                               selectors: [],
                                               page: 1,
                                               per_page: 5,
                                               order_by: 'created_at',
                                               include: ['selector_resource', 'route']
                                             })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AccessRulesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AccessRulesListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'include validations' do
        it 'accepts valid include values' do
          message = AccessRulesListMessage.from_params({ 'include' => 'selector_resource' })
          expect(message).to be_valid

          message = AccessRulesListMessage.from_params({ 'include' => 'route' })
          expect(message).to be_valid

          message = AccessRulesListMessage.from_params({ 'include' => 'selector_resource,route' })
          expect(message).to be_valid
        end

        it 'rejects invalid include values' do
          message = AccessRulesListMessage.from_params({ 'include' => 'invalid' })
          expect(message).not_to be_valid
        end
      end

      describe 'validations' do
        it 'validates space_guids is an array' do
          message = AccessRulesListMessage.from_params space_guids: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:space_guids].length).to eq 1
        end

        it 'allows space_guids to be nil' do
          message = AccessRulesListMessage.from_params({})
          expect(message).to be_valid
          expect(message.space_guids).to be_nil
        end

        it 'allows space_guids to be an array' do
          message = AccessRulesListMessage.from_params space_guids: %w[space1 space2]
          expect(message).to be_valid
          expect(message.space_guids).to eq(%w[space1 space2])
        end
      end
    end
  end
end
