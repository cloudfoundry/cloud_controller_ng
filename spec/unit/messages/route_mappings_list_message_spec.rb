require 'spec_helper'
require 'messages/route_mappings_list_message'

module VCAP::CloudController
  describe RouteMappingsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct RouteMappingsListMessage' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message).to be_a(RouteMappingsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end
    end

    describe '#to_params_hash' do
      let(:opts) do
        {
          page:      1,
          per_page:  5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = []
        expect(RouteMappingsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = TasksListMessage.new({
          page: 1,
          per_page: 5,
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = TasksListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = TasksListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it_behaves_like 'a page validator'
        it_behaves_like 'a per_page validator'
      end
    end
  end
end
