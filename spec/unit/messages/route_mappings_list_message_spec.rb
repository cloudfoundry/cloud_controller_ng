require 'spec_helper'
require 'messages/route_mappings_list_message'

module VCAP::CloudController
  RSpec.describe RouteMappingsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'        => 1,
          'per_page'    => 5,
          'order_by'    => 'phone',
          'app_guid'    => 'app-guid',
          'app_guids'   => 'guid1,guid2',
          'route_guids' => 'guid3,guid4'
        }
      end

      it 'returns the correct RouteMappingsListMessage' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message).to be_a(RouteMappingsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('phone')
        expect(message.app_guid).to eq('app-guid')
        expect(message.app_guids).to match_array(['guid1', 'guid2'])
        expect(message.route_guids).to match_array(['guid3', 'guid4'])
      end

      it 'converts requested keys to symbols' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
      end
    end

    describe '#to_params_hash' do
      let(:opts) do
        {
          app_guid: 'yodawg',
        }
      end

      it 'app_guid' do
        expected_params = []
        expect(RouteMappingsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = RouteMappingsListMessage.new({
          page:        1,
          per_page:    5,
          order_by:    'created_at',
          app_guid:    'app-guid',
          app_guids:   'some-guid,other-guid',
          route_guids: 'guid-a,guid-b'
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = RouteMappingsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = RouteMappingsListMessage.new(foobar: 'pants')

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
