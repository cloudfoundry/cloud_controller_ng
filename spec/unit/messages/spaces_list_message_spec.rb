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
        expect(message.names).to eql(['foo', 'bar'])
        expect(message.organization_guids).to eql(['org1-guid', 'org2-guid'])
        expect(message.guids).to eql(['space1-guid', 'space2-guid'])
        expect(message.include).to eql(['organization'])
      end

      it 'converts requested keys to symbols' do
        message = SpacesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
      end
    end

    describe 'validations' do
      it 'validates names is an array' do
        message = SpacesListMessage.from_params names: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:names].length).to eq 1
      end

      it 'validates organization_guids is an array' do
        message = SpacesListMessage.from_params organization_guids: 'not array'
        expect(message).to be_invalid
        expect(message.errors[:organization_guids].length).to eq 1
      end

      it 'validates guids is an array' do
        message = SpacesListMessage.from_params guids: 'not array'
        expect(message).to be_invalid
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
        expect(message).to be_invalid
        message = SpacesListMessage.from_params 'include' => 'org,spaceship'
        expect(message).to be_invalid
      end
    end
  end
end
