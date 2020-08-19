require 'spec_helper'
require 'messages/service_credential_bindings_show_message'

module VCAP::CloudController
  RSpec.describe ServiceCredentialBindingsShowMessage do
    subject(:message) { described_class.from_params(params) }

    let(:params) do
      {
        'include' => 'app'
      }
    end

    describe '.from_params' do
      it 'returns the correct ServiceCredentialBindingsShowMessage' do
        expect(message).to be_a(ServiceCredentialBindingsShowMessage)
        expect(message.include).to match_array(['app'])
      end

      it 'converts requested keys to symbols' do
        expect(message.requested?(:include)).to be_truthy
      end
    end

    describe '#valid?' do
      it 'returns true for valid fields' do
        message = described_class.from_params(params)
        expect(message).to be_valid
      end

      it 'returns true for empty fields' do
        message = described_class.from_params({})
        expect(message).to be_valid
      end

      it 'returns false for invalid fields' do
        message = described_class.from_params({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'include' do
        it 'returns false for arbitrary values' do
          message = described_class.from_params({ 'include' => 'route' })
          expect(message).not_to be_valid
          expect(message.errors[:base]).to include(include("Invalid included resource: 'route'"))
        end

        it 'returns true for valid values' do
          message = described_class.from_params({ 'include' => 'app' })
          expect(message).to be_valid
        end
      end
    end
  end
end
