require 'spec_helper'
require 'messages/domains_list_message'

module VCAP::CloudController
  RSpec.describe DomainsListMessage do
    describe '.from_params' do
      let(:params) do
        { 'label_selector' => 'animal in (cat,dog)' }
      end

      it 'returns the correct DomainsListMessage' do
        message = DomainsListMessage.from_params(params)

        expect(message).to be_a(DomainsListMessage)
        expect(message.label_selector).to eq('animal in (cat,dog)')
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = DomainsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a names param' do
        message = DomainsListMessage.from_params({ 'names' => 'test.com,foo.com' })
        expect(message).to be_valid
      end

      it 'accepts a guids param' do
        message = DomainsListMessage.from_params({ 'guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.guids).to eq(%w[guid1 guid2])
      end

      it 'accepts an organization_guids param' do
        message = DomainsListMessage.from_params({ 'organization_guids' => 'guid1,guid2' })
        expect(message).to be_valid
      end

      it 'does not accept any other params' do
        message = DomainsListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates requirements' do
          message = DomainsListMessage.from_params('label_selector' => '')

          expect_any_instance_of(Validators::LabelSelectorRequirementValidator).to receive(:validate).with(message).and_call_original
          message.valid?
        end

        it 'validates guids' do
          message = DomainsListMessage.from_params({ guids: 'not an array' })
          expect(message).to be_invalid
          expect(message.errors[:guids]).to include('must be an array')
        end
      end
    end
  end
end
