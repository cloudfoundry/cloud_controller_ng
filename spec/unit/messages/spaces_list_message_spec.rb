require 'spec_helper'
require 'messages/spaces/spaces_list_message'

module VCAP::CloudController
  RSpec.describe SpacesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'names' => 'foo,bar',
          'organization_guids' => 'org1-guid,org2-guid'
        }
      end

      it 'returns the correct SpacesListMessage' do
        message = SpacesListMessage.from_params(params)

        expect(message).to be_a(SpacesListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.names).to eql(['foo', 'bar'])
        expect(message.organization_guids).to eql(['org1-guid', 'org2-guid'])
      end

      it 'converts requested keys to symbols' do
        message = SpacesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
      end
    end

    describe 'validations' do
      it 'validates names is an array' do
        message = SpacesListMessage.new names: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:names].length).to eq 1
      end

      it 'validates organization_guids is an array' do
        message = SpacesListMessage.new organization_guids: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:organization_guids].length).to eq 1
      end
    end
  end
end
