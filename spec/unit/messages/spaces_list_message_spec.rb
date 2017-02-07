require 'spec_helper'
require 'messages/spaces/spaces_list_message'

module VCAP::CloudController
  RSpec.describe SpacesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'names' => 'foo,bar'
        }
      end

      it 'returns the correct SpacesListMessage' do
        message = SpacesListMessage.from_params(params)

        expect(message).to be_a(SpacesListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.names).to eql(['foo', 'bar'])
      end

      it 'converts requested keys to symbols' do
        message = SpacesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = SpacesListMessage.new names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end
      end
    end
  end
end
