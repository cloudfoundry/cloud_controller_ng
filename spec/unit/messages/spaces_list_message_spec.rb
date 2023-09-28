require 'spec_helper'
require 'messages/spaces_list_message'

module VCAP::CloudController
  RSpec.describe SpacesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'names' => 'foo,bar',
          'organization_guids' => 'org1-guid,org2-guid',
          'guids' => 'space1-guid,space2-guid',
          'include' => 'organization'
        }
      end

      it 'returns the correct SpacesListMessage' do
        message = SpacesListMessage.from_params(params)

        expect(message).to be_a(SpacesListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.names).to eql(%w[foo bar])
        expect(message.organization_guids).to eql(%w[org1-guid org2-guid])
        expect(message.guids).to eql(%w[space1-guid space2-guid])
        expect(message.include).to eql(['organization'])
      end

      it 'converts requested keys to symbols' do
        message = SpacesListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:names)
        expect(message).to be_requested(:organization_guids)
        expect(message).to be_requested(:guids)
      end
    end

    describe 'validations' do
      it 'validates names is an array' do
        message = SpacesListMessage.from_params names: 'not array'
        expect(message).not_to be_valid
        expect(message.errors[:names].length).to eq 1
      end

      it 'validates organization_guids is an array' do
        message = SpacesListMessage.from_params organization_guids: 'not array'
        expect(message).not_to be_valid
        expect(message.errors[:organization_guids].length).to eq 1
      end

      it 'validates guids is an array' do
        message = SpacesListMessage.from_params guids: 'not array'
        expect(message).not_to be_valid
        expect(message.errors[:guids].length).to eq 1
      end

      it 'validates requirements' do
        message = SpacesListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).to receive(:validate).with(message).and_call_original
        message.valid?
      end

      it 'validates possible includes' do
        message = SpacesListMessage.from_params 'include' => 'org'
        expect(message).to be_valid
        message = SpacesListMessage.from_params 'include' => 'organization'
        expect(message).to be_valid
        message = SpacesListMessage.from_params 'include' => 'spaceship'
        expect(message).not_to be_valid
        message = SpacesListMessage.from_params 'include' => 'org,spaceship'
        expect(message).not_to be_valid
      end
    end
  end
end
